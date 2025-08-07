#include "dobby.h"
#include <android/log.h>
#include <jni.h>
#include <sys/system_properties.h>
#include <unordered_map>
#include <vector>
#include <string>
#include <fstream>
#include <sstream>
#include <random>
#include <unistd.h>
#include <dlfcn.h>

#define LOGD(...) __android_log_print(ANDROID_LOG_DEBUG, "PIF_ALT", __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, "PIF_ALT", __VA_ARGS__)
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, "PIF_ALT", __VA_ARGS__)

namespace PIF {
    static std::string dir;
    static JNIEnv *env;
    static bool isGmsUnstable = false;
    static bool isVending = false;
    static bool advancedHiding = true;

    static std::unordered_map<std::string, std::string> propMap;
    static std::vector<std::string> sensitiveProps = {
        "ro.build.fingerprint",
        "ro.product.model",
        "ro.product.device",
        "ro.build.version.release",
        "ro.build.version.security_patch",
        "ro.build.id",
        "init.svc.su",
        "init.svc.magisk"
    };

    static bool spoofBuild = true, spoofProps = true, spoofProvider = false, spoofSignature = false;
    static bool DEBUG = false;
    static std::string DEVICE_INITIAL_SDK_INT = "21", SECURITY_PATCH, BUILD_ID;
    static bool spoofVendingSdk = false;

    typedef void (*T_Callback)(void *, const char *, const char *, uint32_t);
    static T_Callback o_callback = nullptr;

    static std::string randomizeProperty(const std::string& value) {
        static std::random_device rd;
        static std::mt19937 gen(rd());
        static std::uniform_int_distribution<> dis(1000, 9999);
        if (value.empty()) return value;
        return value + "_" + std::to_string(dis(gen));
    }

    static void modify_callback(void *cookie, const char *name, const char *value, uint32_t serial) {
        if (!cookie || !name || !value || !o_callback) return;

        std::string prop(name);
        std::string newValue = value;

        if (prop == "init.svc.adbd") {
            newValue = "stopped";
        } else if (prop == "sys.usb.state") {
            newValue = "mtp";
        } else if (prop.find("api_level") != std::string::npos) {
            if (!DEVICE_INITIAL_SDK_INT.empty()) {
                newValue = DEVICE_INITIAL_SDK_INT;
            }
        } else if (prop.find(".security_patch") != std::string::npos) {
            if (!SECURITY_PATCH.empty()) {
                newValue = SECURITY_PATCH;
            }
        } else if (prop.find(".build.id") != std::string::npos) {
            if (!BUILD_ID.empty()) {
                newValue = BUILD_ID;
            }
        } else if (advancedHiding && std::find(sensitiveProps.begin(), sensitiveProps.end(), prop) != sensitiveProps.end()) {
            newValue = randomizeProperty(newValue);
        }

        if (newValue != value) {
            LOGD("[MODIFY] %s: %s -> %s", name, value, newValue.c_str());
        } else if (DEBUG) {
            LOGD("[UNCHANGED] %s: %s", name, value);
        }

        o_callback(cookie, name, newValue.c_str(), serial);
    }

    static void (*o_system_property_read_callback)(prop_info *, T_Callback, void *) = nullptr;

    static void my_system_property_read_callback(prop_info *pi, T_Callback callback, void *cookie) {
        if (pi && callback && cookie) o_callback = callback;
        o_system_property_read_callback(pi, modify_callback, cookie);
    }

    static int (*o_system_property_get)(const char *, char *) = nullptr;

    static int my_system_property_get(const char *name, char *buffer) {
        if (!name) return 0;
        if (!buffer) return o_system_property_get(name, buffer);

        char temp[PROP_VALUE_MAX];
        int len = o_system_property_get(name, temp);
        if (len <= 0) return len;

        std::string prop(name);
        std::string currentValue(temp);
        std::string newValue = currentValue;

        if (advancedHiding && std::find(sensitiveProps.begin(), sensitiveProps.end(), prop) != sensitiveProps.end()) {
            newValue = randomizeProperty(currentValue);
            if (newValue.length() >= PROP_VALUE_MAX) {
                newValue.resize(PROP_VALUE_MAX - 1);
            }
            strcpy(buffer, newValue.c_str());
            len = newValue.length();
            LOGD("[GET_PROP] %s: %s -> %s", name, currentValue.c_str(), buffer);
        } else {
            strcpy(buffer, temp);
        }

        return len;
    }

    static bool doHook() {
        void *ptr = DobbySymbolResolver(nullptr, "__system_property_read_callback");
        if (ptr && DobbyHook(ptr, (void *)my_system_property_read_callback, (void **)&o_system_property_read_callback) == 0) {
            LOGD("Hooked __system_property_read_callback at %p", ptr);
        } else {
            LOGE("Failed to hook __system_property_read_callback");
            return false;
        }
        
        ptr = DobbySymbolResolver(nullptr, "__system_property_get");
        if (ptr && DobbyHook(ptr, (void *)my_system_property_get, (void **)&o_system_property_get) == 0) {
            LOGD("Hooked __system_property_get at %p", ptr);
        } else {
            LOGE("Failed to hook __system_property_get");
            return false;
        }

        return true;
    }

    static void doSpoofVending() {
        int requestSdk = 32;
        jclass buildVersionClass = env->FindClass("android/os/Build$VERSION");
        if (!buildVersionClass) {
            env->ExceptionClear();
            return;
        }
        jfieldID sdkIntFieldID = env->GetStaticFieldID(buildVersionClass, "SDK_INT", "I");
        if (!sdkIntFieldID) {
            env->ExceptionClear();
            env->DeleteLocalRef(buildVersionClass);
            return;
        }
        int oldValue = env->GetStaticIntField(buildVersionClass, sdkIntFieldID);
        int targetSdk = (oldValue < requestSdk) ? oldValue : requestSdk;
        if (oldValue != targetSdk) {
            env->SetStaticIntField(buildVersionClass, sdkIntFieldID, targetSdk);
            if (env->ExceptionCheck()) {
                env->ExceptionClear();
            } else {
                LOGD("[SDK_INT] %d -> %d", oldValue, targetSdk);
            }
        }
        env->DeleteLocalRef(buildVersionClass);
    }

    static void parsePropFile(const std::string& path) {
        propMap.clear();
        std::ifstream file(path);
        if (!file.is_open()) {
            LOGE("Failed to open prop file: %s", path.c_str());
            return;
        }
        std::string line;
        while (std::getline(file, line)) {
            size_t commentPos = line.find('#');
            if (commentPos != std::string::npos) line = line.substr(0, commentPos);
            line.erase(0, line.find_first_not_of(" \t\r\n"));
            line.erase(line.find_last_not_of(" \t\r\n") + 1);
            if (line.empty()) continue;
            size_t eqPos = line.find('=');
            if (eqPos == std::string::npos) continue;
            std::string key = line.substr(0, eqPos);
            std::string value = line.substr(eqPos + 1);
            propMap[key] = value;
        }
        file.close();
    }

    static void parseProps() {
        if (propMap.count("spoofVendingSdk")) {
            spoofVendingSdk = (propMap["spoofVendingSdk"] == "1" || propMap["spoofVendingSdk"] == "true");
            propMap.erase("spoofVendingSdk");
        }
        if (propMap.count("advancedHiding")) {
            advancedHiding = (propMap["advancedHiding"] == "1" || propMap["advancedHiding"] == "true");
            propMap.erase("advancedHiding");
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
            spoofBuild = (propMap["spoofBuild"] == "1" || propMap["spoofBuild"] == "true");
            propMap.erase("spoofBuild");
        }
        if (propMap.count("spoofProvider")) {
            spoofProvider = (propMap["spoofProvider"] == "1" || propMap["spoofProvider"] == "true");
            propMap.erase("spoofProvider");
        }
        if (propMap.count("spoofProps")) {
            spoofProps = (propMap["spoofProps"] == "1" || propMap["spoofProps"] == "true");
            propMap.erase("spoofProps");
        }
        if (propMap.count("spoofSignature")) {
            spoofSignature = (propMap["spoofSignature"] == "1" || propMap["spoofSignature"] == "true");
            propMap.erase("spoofSignature");
        }
        if (propMap.count("DEBUG")) {
            DEBUG = (propMap["DEBUG"] == "1" || propMap["DEBUG"] == "true");
            propMap.erase("DEBUG");
        }
        if (propMap.count("FINGERPRINT")) {
            std::string fingerprint = propMap["FINGERPRINT"];
            std::vector<std::string> colonParts;
            std::istringstream iss(fingerprint);
            std::string part;
            while (std::getline(iss, part, ':')) {
                colonParts.push_back(part);
            }
            if (colonParts.size() >= 3) {
                std::vector<std::string> brandParts;
                std::istringstream issBrand(colonParts[0]);
                while (std::getline(issBrand, part, '/')) {
                    brandParts.push_back(part);
                }
                if (brandParts.size() >= 3) {
                    propMap["BRAND"] = brandParts[0];
                    propMap["PRODUCT"] = brandParts[1];
                    propMap["DEVICE"] = brandParts[2];
                }
                std::vector<std::string> versionParts;
                std::istringstream issVersion(colonParts[1]);
                while (std::getline(issVersion, part, '/')) {
                    versionParts.push_back(part);
                }
                if (versionParts.size() >= 3) {
                    propMap["RELEASE"] = versionParts[0];
                    propMap["ID"] = versionParts[1];
                    propMap["INCREMENTAL"] = versionParts[2];
                }
                std::vector<std::string> typeParts;
                std::istringstream issType(colonParts[2]);
                while (std::getline(issType, part, '/')) {
                    typeParts.push_back(part);
                }
                if (!typeParts.empty()) {
                    propMap["TYPE"] = typeParts[0];
                    if (typeParts.size() > 1) {
                        propMap["TAGS"] = typeParts[1];
                    }
                }
            }
            propMap.erase("FINGERPRINT");
        }
        if (propMap.count("SECURITY_PATCH")) {
            SECURITY_PATCH = propMap["SECURITY_PATCH"];
        }
        if (propMap.count("ID")) {
            BUILD_ID = propMap["ID"];
        }
    }

    static void UpdateBuildFields() {
        jclass buildClass = env->FindClass("android/os/Build");
        jclass versionClass = env->FindClass("android/os/Build$VERSION");
        for (const auto& [key, val] : propMap) {
            jfieldID fieldID = env->GetStaticFieldID(buildClass, key.c_str(), "Ljava/lang/String;");
            if (env->ExceptionCheck()) {
                env->ExceptionClear();
                fieldID = env->GetStaticFieldID(versionClass, key.c_str(), "Ljava/lang/String;");
                if (env->ExceptionCheck()) {
                    env->ExceptionClear();
                    continue;
                }
            }
            if (fieldID) {
                jstring jValue = env->NewStringUTF(val.c_str());
                env->SetStaticObjectField(buildClass, fieldID, jValue);
                if (env->ExceptionCheck()) {
                    env->ExceptionClear();
                } else {
                    LOGD("Set '%s' to '%s'", key.c_str(), val.c_str());
                }
                env->DeleteLocalRef(jValue);
            }
        }
        env->DeleteLocalRef(buildClass);
        env->DeleteLocalRef(versionClass);
    }

    static std::string propMapToJson() {
        std::ostringstream json;
        json << "{";
        bool first = true;
        for (const auto& [k, v] : propMap) {
            if (!first) json << ",";
            first = false;
            json << "\"" << k << "\":\"" << v << "\"";
        }
        json << "}";
        return json.str();
    }

    static bool validateDexFile(const std::string& path) {
        std::ifstream file(path, std::ios::binary | std::ios::ate);
        return file.is_open() && file.tellg() > 0;
    }

    static void injectDex() {
        std::string dexPath = dir + "/classes.dex";
        if (!validateDexFile(dexPath)) {
            LOGE("Dex file validation failed: %s", dexPath.c_str());
            return;
        }

        jclass clClass = env->FindClass("java/lang/ClassLoader");
        if (!clClass) {
            env->ExceptionClear();
            return;
        }

        jmethodID getSystemClassLoader = env->GetStaticMethodID(clClass, "getSystemClassLoader", "()Ljava/lang/ClassLoader;");
        jobject systemClassLoader = env->CallStaticObjectMethod(clClass, getSystemClassLoader);
        if (env->ExceptionCheck()) {
            env->ExceptionClear();
            env->DeleteLocalRef(clClass);
            return;
        }

        jclass dexClClass = env->FindClass("dalvik/system/PathClassLoader");
        if (!dexClClass) {
            env->ExceptionClear();
            env->DeleteLocalRef(clClass);
            return;
        }

        jmethodID dexClInit = env->GetMethodID(dexClClass, "<init>", "(Ljava/lang/String;Ljava/lang/ClassLoader;)V");
        jstring classesJar = env->NewStringUTF(dexPath.c_str());
        jobject dexCl = env->NewObject(dexClClass, dexClInit, classesJar, systemClassLoader);
        if (env->ExceptionCheck()) {
            env->ExceptionClear();
            env->DeleteLocalRef(classesJar);
            env->DeleteLocalRef(dexClClass);
            env->DeleteLocalRef(clClass);
            return;
        }

        jmethodID loadClass = env->GetMethodID(clClass, "loadClass", "(Ljava/lang/String;)Ljava/lang/Class;");
        jstring entryClassName = env->NewStringUTF("es.chiteroman.playintegrityfix.EntryPoint");
        jobject entryClassObj = env->CallObjectMethod(dexCl, loadClass, entryClassName);
        jclass entryPointClass = static_cast<jclass>(entryClassObj);
        if (env->ExceptionCheck() || !entryPointClass) {
            env->ExceptionClear();
            env->DeleteLocalRef(entryClassName);
            env->DeleteLocalRef(entryClassObj);
            env->DeleteLocalRef(dexCl);
            env->DeleteLocalRef(classesJar);
            env->DeleteLocalRef(dexClClass);
            env->DeleteLocalRef(clClass);
            return;
        }

        jmethodID entryInit = env->GetStaticMethodID(entryPointClass, "init", "(Ljava/lang/String;ZZZ)V");
        jstring jsonStr = env->NewStringUTF(propMapToJson().c_str());
        env->CallStaticVoidMethod(entryPointClass, entryInit, jsonStr, spoofProvider, spoofSignature, spoofBuild);
        if (env->ExceptionCheck()) {
            env->ExceptionClear();
        }

        env->DeleteLocalRef(entryClassName);
        env->DeleteLocalRef(entryClassObj);
        env->DeleteLocalRef(jsonStr);
        env->DeleteLocalRef(dexCl);
        env->DeleteLocalRef(classesJar);
        env->DeleteLocalRef(dexClClass);
        env->DeleteLocalRef(clClass);
    }

    static void maskSensitivePaths() {
        if (!advancedHiding) return;
        std::vector<std::string> sensitivePaths = {"/system/xbin/su", "/data/adb/magisk"};
        for (const auto& path : sensitivePaths) {
            if (access(path.c_str(), F_OK) == 0) {
                LOGI("Masking sensitive path: %s", path.c_str());
            }
        }
    }
}

extern "C" [[gnu::visibility("default"), maybe_unused]] bool
init(JavaVM *vm, const std::string &gmsDir, bool isGmsUnstable, bool isVending) {
    PIF::isGmsUnstable = isGmsUnstable;
    PIF::isVending = isVending;

    if (vm->GetEnv(reinterpret_cast<void **>(&PIF::env), JNI_VERSION_1_6) != JNI_OK) {
        return true;
    }

    PIF::dir = gmsDir;
    LOGD("[INJECT] GMS dir: %s", PIF::dir.c_str());

    PIF::parsePropFile(PIF::dir + "/pif.prop");
    PIF::parseProps();

    PIF::maskSensitivePaths();

    if (PIF::isGmsUnstable) {
        if (PIF::spoofBuild) {
            PIF::UpdateBuildFields();
        }

        if (PIF::spoofProvider || PIF::spoofSignature) {
            PIF::injectDex();
        } else {
            LOGD("[INJECT] Dex injection skipped");
        }

        if (PIF::spoofProps) {
            return !PIF::doHook();
        }
    } else if (PIF::isVending && PIF::spoofVendingSdk) {
        PIF::doSpoofVending();
    }

    return true;
}