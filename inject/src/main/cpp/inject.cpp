// Synced with latest PlayIntegrityFix fork by KOWX712
// All the credits to chiteroman & kowx712.
#include "dobby.h"
#include <android/log.h>
#include <jni.h>
#include <sys/system_properties.h>
#include <unordered_map>
#include <vector>

#define LOGD(...) __android_log_print(ANDROID_LOG_DEBUG, "PIF", __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, "PIF", __VA_ARGS__)


static bool spoofUserBuild = true;
static bool spoofAbi = true;
static bool spoofLocale = true;

static std::string dir;
static JNIEnv *env;
static bool isGmsUnstable = false;
static bool isVending = false;

static std::unordered_map<std::string, std::string> propMap;

static bool spoofBuild = true, spoofProps = true, spoofProvider = true, spoofSignature = false;

static std::string DEVICE_INITIAL_SDK_INT = "21", SECURITY_PATCH, BUILD_ID;
static bool spoofVendingSdk = false;

static std::string BUILD_RELEASE;
static std::string BUILD_TYPE = "user";
static std::string BUILD_TAGS = "release-keys";
static std::string RO_DEBUGGABLE = "0";
static std::string RO_SECURE = "1";
static std::string VERIFIED_BOOT_STATE = "green";
static std::string FLASH_LOCKED = "1";
static std::string VBMETA_STATE = "locked";

typedef void (*T_Callback)(void *, const char *, const char *, uint32_t);

static T_Callback o_callback = nullptr;

static void modify_callback(void *cookie, const char *name, const char *value,
                            uint32_t serial) {

    if (!cookie || !name || !value || !o_callback)
        return;

    const char *oldValue = value;

    std::string_view prop(name);

    if (prop == "init.svc.adbd") {
        value = "stopped";
    } else if (prop == "sys.usb.state") {
        value = "mtp";
    } else if (prop.ends_with("api_level")) {
        if (!DEVICE_INITIAL_SDK_INT.empty()) {
            value = DEVICE_INITIAL_SDK_INT.c_str();
        }
    } else if (prop.ends_with(".security_patch")) {
        if (!SECURITY_PATCH.empty()) {
            value = SECURITY_PATCH.c_str();
        }
    } else if (prop.ends_with(".build.id")) {
        if (!BUILD_ID.empty()) {
            value = BUILD_ID.c_str();
        }
    }

    else if (prop == "ro.build.version.release") {
        if (!BUILD_RELEASE.empty()) {
            value = BUILD_RELEASE.c_str();
        }
    } else if (prop == "ro.build.type") {
        value = BUILD_TYPE.c_str();
    } else if (prop == "ro.build.tags") {
        value = BUILD_TAGS.c_str();
    } else if (prop == "ro.debuggable") {
        value = RO_DEBUGGABLE.c_str();
    } else if (prop == "ro.secure") {
        value = RO_SECURE.c_str();
    } else if (prop == "ro.boot.verifiedbootstate") {
        value = VERIFIED_BOOT_STATE.c_str();
    } else if (prop == "ro.boot.flash.locked") {
        value = FLASH_LOCKED.c_str();
    } else if (prop == "ro.boot.vbmeta.device_state") {
        value = VBMETA_STATE.c_str();
    }

    if (strcmp(oldValue, value) == 0) {
        LOGD("[%s]: %s (unchanged)", name, oldValue);
    } else {
        LOGD("[%s]: %s -> %s", name, oldValue, value);
    }

    return o_callback(cookie, name, value, serial);
}

static void (*o_system_property_read_callback)(prop_info *, T_Callback,
                                               void *) = nullptr;

static void my_system_property_read_callback(prop_info *pi, T_Callback callback,
                                             void *cookie) {
    if (pi && callback && cookie)
        o_callback = callback;
    return o_system_property_read_callback(pi, modify_callback, cookie);
}

static bool doHook() {
    void *ptr = DobbySymbolResolver(nullptr, "__system_property_read_callback");

    if (ptr && DobbyHook(ptr, (void *) my_system_property_read_callback,
                         (void **) &o_system_property_read_callback) == 0) {
        LOGD("hook __system_property_read_callback successful at %p", ptr);
        return true;
    }

    LOGE("hook __system_property_read_callback failed!");
    return false;
}

static void doSpoofVending() {
    int requestSdk = 32;
    int targetSdk;
    int oldValue;

    jclass buildVersionClass = nullptr;
    jfieldID sdkIntFieldID = nullptr;

    buildVersionClass = env->FindClass("android/os/Build$VERSION");
    if (buildVersionClass == nullptr) {
        LOGE("Build.VERSION class not found");
        env->ExceptionClear();
        return;
    }

    sdkIntFieldID = env->GetStaticFieldID(buildVersionClass, "SDK_INT", "I");
    if (sdkIntFieldID == nullptr) {
        LOGE("SDK_INT field not found");
        env->ExceptionClear();
        env->DeleteLocalRef(buildVersionClass);
        return;
    }

    oldValue = env->GetStaticIntField(buildVersionClass, sdkIntFieldID);
    targetSdk = std::min(oldValue, requestSdk);

    if (oldValue == targetSdk) {
        env->DeleteLocalRef(buildVersionClass);
        return;
    }

    env->SetStaticIntField(buildVersionClass, sdkIntFieldID, targetSdk);

    if (env->ExceptionCheck()) {
        env->ExceptionDescribe();
        env->ExceptionClear();
        LOGE("SDK_INT field not accessible (JNI Exception)");
    } else {
        LOGE("[SDK_INT]: %d -> %d", oldValue, targetSdk);
    }

    env->DeleteLocalRef(buildVersionClass);
}

static void parsePropFile(const std::string& path) {
    propMap.clear();
    FILE* file = fopen(path.c_str(), "r");
    if (!file) return;
    char buf[512];
    while (fgets(buf, sizeof(buf), file)) {
        std::string line(buf);
        auto comment = line.find('#');
        if (comment != std::string::npos) line = line.substr(0, comment);
        line.erase(0, line.find_first_not_of(" \t\r\n"));
        line.erase(line.find_last_not_of(" \t\r\n") + 1);
        if (line.empty()) continue;
        auto eq = line.find('=');
        if (eq == std::string::npos) continue;
        std::string key = line.substr(0, eq);
        std::string value = line.substr(eq + 1);
        propMap[key] = value;
    }
    fclose(file);
}

static void parseProps() {
    if (propMap.count("spoofVendingSdk")) {
        std::string v = propMap["spoofVendingSdk"];
        spoofVendingSdk = (v == "1" || v == "true");
        propMap.erase("spoofVendingSdk");
    }
    if (isVending) {
        propMap.clear();
        return;
    }
    if (propMap.count("DEVICE_INITIAL_SDK_INT")) {
        DEVICE_INITIAL_SDK_INT = propMap["DEVICE_INITIAL_SDK_INT"];
        propMap.erase("DEVICE_INITIAL_SDK_INT");
    }
    if (propMap.count("spoofBuild")) {
        std::string v = propMap["spoofBuild"];
        spoofBuild = (v == "1" || v == "true");
        propMap.erase("spoofBuild");
    }
    if (propMap.count("spoofProvider")) {
        std::string v = propMap["spoofProvider"];
        spoofProvider = (v == "1" || v == "true");
        propMap.erase("spoofProvider");
    }
    if (propMap.count("spoofProps")) {
        std::string v = propMap["spoofProps"];
        spoofProps = (v == "1" || v == "true");
        propMap.erase("spoofProps");
    }
    if (propMap.count("spoofSignature")) {
        std::string v = propMap["spoofSignature"];
        spoofSignature = (v == "1" || v == "true");
        propMap.erase("spoofSignature");
    }
    if (propMap.count("FINGERPRINT")) {
        std::string fingerprint = propMap["FINGERPRINT"];
        std::vector<std::string> vector;
        size_t start = 0, end;
        while ((end = fingerprint.find('/', start)) != std::string::npos) {
            std::string part = fingerprint.substr(start, end - start);
            size_t sub_start = 0, sub_end;
            while ((sub_end = part.find(':', sub_start)) != std::string::npos) {
                vector.push_back(part.substr(sub_start, sub_end - sub_start));
                sub_start = sub_end + 1;
            }
            vector.push_back(part.substr(sub_start));
            start = end + 1;
        }
        std::string part = fingerprint.substr(start);
        size_t sub_start = 0, sub_end;
        while ((sub_end = part.find(':', sub_start)) != std::string::npos) {
            vector.push_back(part.substr(sub_start, sub_end - sub_start));
            sub_start = sub_end + 1;
        }
        vector.push_back(part.substr(sub_start));

        static const char* keys[] = {
            "BRAND",
            "PRODUCT",
            "DEVICE",
            "RELEASE",
            "ID",
            "INCREMENTAL",
            "TYPE",
            "TAGS"
        };
        for (size_t i = 0; i < 8; ++i) {
            propMap[keys[i]] = (i < vector.size()) ? vector[i] : "";
        }
    }
    if (propMap.count("SECURITY_PATCH")) {
        SECURITY_PATCH = propMap["SECURITY_PATCH"];
    }
    if (propMap.count("ID")) {
        BUILD_ID = propMap["ID"];
    }
    
    if (propMap.count("RELEASE")) {
        BUILD_RELEASE = propMap["RELEASE"];
    }
    if (propMap.count("TYPE")) {
        BUILD_TYPE = propMap["TYPE"];
    }
    if (propMap.count("TAGS")) {
        BUILD_TAGS = propMap["TAGS"];
    }
    if (propMap.count("ro.debuggable"))     {
        RO_DEBUGGABLE = propMap["ro.debuggable"];
        propMap.erase("ro.debuggable");
    }
    if (propMap.count("ro.secure")) {
        RO_SECURE = propMap["ro.secure"];
        propMap.erase("ro.secure");
    }
    if (propMap.count("ro.boot.verifiedbootstate")) {
        VERIFIED_BOOT_STATE = propMap["ro.boot.verifiedbootstate"];
        propMap.erase("ro.boot.verifiedbootstate");
    }
    if (propMap.count("ro.boot.flash.locked")) {
        FLASH_LOCKED = propMap["ro.boot.flash.locked"];
        propMap.erase("ro.boot.flash.locked");
    }
    if (propMap.count("ro.boot.vbmeta.device_state")) {
        VBMETA_STATE = propMap["ro.boot.vbmeta.device_state"];
        propMap.erase("ro.boot.vbmeta.device_state");
    }
}

static void UpdateBuildFields() {
    jclass buildClass = env->FindClass("android/os/Build");
    jclass versionClass = env->FindClass("android/os/Build$VERSION");
    for (const auto& [key, val] : propMap) {
        const char *fieldName = key.c_str();

        jfieldID fieldID =
                env->GetStaticFieldID(buildClass, fieldName, "Ljava/lang/String;");

        if (env->ExceptionCheck()) {
            env->ExceptionClear();

            fieldID =
                    env->GetStaticFieldID(versionClass, fieldName, "Ljava/lang/String;");

            if (env->ExceptionCheck()) {
                env->ExceptionClear();
                continue;
            }
        }

        if (fieldID != nullptr) {
            const char *value = val.c_str();
            jstring jValue = env->NewStringUTF(value);

            env->SetStaticObjectField(buildClass, fieldID, jValue);
            if (env->ExceptionCheck()) {
                env->ExceptionClear();
                continue;
            }

            LOGD("Set '%s' to '%s'", fieldName, value);
        }
    }
}

static std::string propMapToJson() {
    std::string json = "{";
    bool first = true;
    for (const auto& [k, v] : propMap) {
        if (!first) json += ",";
        first = false;
        json += "\"" + k + "\":\"" + v + "\"";
    }
    json += "}";
    return json;
}

static void injectDex() {
    LOGD("get system classloader");
    auto clClass = env->FindClass("java/lang/ClassLoader");
    auto getSystemClassLoader = env->GetStaticMethodID(
            clClass, "getSystemClassLoader", "()Ljava/lang/ClassLoader;");
    auto systemClassLoader =
            env->CallStaticObjectMethod(clClass, getSystemClassLoader);

    if (env->ExceptionCheck()) {
        env->ExceptionDescribe();
        env->ExceptionClear();
        return;
    }

    LOGD("create class loader");
    auto dexClClass = env->FindClass("dalvik/system/PathClassLoader");
    auto dexClInit = env->GetMethodID(
            dexClClass, "<init>",
            "(Ljava/lang/String;Ljava/lang/ClassLoader;)V");
    auto classesJar = env->NewStringUTF((dir + "/classes.dex").c_str());
    auto dexCl =
            env->NewObject(dexClClass, dexClInit, classesJar, systemClassLoader);

    if (env->ExceptionCheck()) {
        env->ExceptionDescribe();
        env->ExceptionClear();
        return;
    }

    LOGD("load class");
    auto loadClass = env->GetMethodID(clClass, "loadClass",
                                      "(Ljava/lang/String;)Ljava/lang/Class;");
    auto entryClassName =
            env->NewStringUTF("es.chiteroman.playintegrityfix.EntryPoint");
    auto entryClassObj = env->CallObjectMethod(dexCl, loadClass, entryClassName);
    auto entryPointClass = (jclass) entryClassObj;

    if (env->ExceptionCheck()) {
        env->ExceptionDescribe();
        env->ExceptionClear();
        return;
    }

    LOGD("call init");
    auto entryInit = env->GetStaticMethodID(entryPointClass, "init",
                                            "(Ljava/lang/String;ZZ)V");
    auto jsonStr = env->NewStringUTF(propMapToJson().c_str());
    env->CallStaticVoidMethod(entryPointClass, entryInit, jsonStr, spoofProvider,
                              spoofSignature);

    if (env->ExceptionCheck()) {
        env->ExceptionDescribe();
        env->ExceptionClear();
    }

    env->DeleteLocalRef(entryClassName);
    env->DeleteLocalRef(entryClassObj);
    env->DeleteLocalRef(jsonStr);
    env->DeleteLocalRef(dexCl);
    env->DeleteLocalRef(classesJar);
    env->DeleteLocalRef(dexClClass);
    env->DeleteLocalRef(clClass);

    LOGD("jni memory free");
}

extern "C" [[gnu::visibility("default"), maybe_unused]] bool
init(JavaVM *vm, const std::string &gmsDir, bool isGmsUnstable, bool isVending) {
    ::isGmsUnstable = isGmsUnstable;
    ::isVending = isVending;

    if (vm->GetEnv(reinterpret_cast<void **>(&env), JNI_VERSION_1_6) != JNI_OK) {
        LOGE("[INJECT] JNI_ERR!");
        return true;
    }

    dir = gmsDir;
    LOGD("[INJECT] GMS dir: %s", dir.c_str());

    parsePropFile(dir + "/pif.prop");
    parseProps();

    if (isGmsUnstable) {
        if (spoofBuild) {
            UpdateBuildFields();
        }

        if (spoofProvider || spoofSignature) {
            injectDex();
        } else {
            LOGD("[INJECT] Dex file won't be injected due spoofProvider and spoofSignature are false");
        }

        if (spoofProps) {
            return !doHook();
        }
    } else if (isVending && spoofVendingSdk) {
        doSpoofVending();
    }

    return true;
}