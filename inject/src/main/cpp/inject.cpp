#include "dobby.h"
#include <android/log.h>
#include <jni.h>
#include <sys/system_properties.h>
#include <unordered_map>
#include <vector>
#include <string>
#include <fstream>
#include <sstream>

#define LOGD(...) __android_log_print(ANDROID_LOG_DEBUG, "PIF_ALT", __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, "PIF_ALT", __VA_ARGS__)

namespace PIF {
    static std::string dir;
    static JNIEnv *env;
    static bool isGmsUnstable = false;
    static bool isVending = false;

    static std::unordered_map<std::string, std::string> propMap;

    static bool spoofBuild = true, spoofProps = true, spoofProvider = false, spoofSignature = false;
    static bool DEBUG = false;
    static std::string DEVICE_INITIAL_SDK_INT = "21", SECURITY_PATCH, BUILD_ID;
    static bool spoofVendingSdk = false;

    typedef void (*T_Callback)(void *, const char *, const char *, uint32_t);
    static T_Callback o_callback = nullptr;

    static void modify_callback(void *cookie, const char *name, const char *value, uint32_t serial) {
        if (!cookie || !name || !value || !o_callback) return;

        std::string prop(name);
        std::string newValue = value;

        if (prop == "init.svc.adbd") {
            newValue = "stopped";
        } else if (prop == "sys.usb.state") {
            newValue = "mtp";
        } else if (prop.ends_with("api_level")) {
            if (!DEVICE_INITIAL_SDK_INT.empty()) {
                newValue = DEVICE_INITIAL_SDK_INT;
            }
        } else if (prop.ends_with(".security_patch")) {
            if (!SECURITY_PATCH.empty()) {
                newValue = SECURITY_PATCH;
            }
        } else if (prop.ends_with(".build.id")) {
            if (!BUILD_ID.empty()) {
                newValue = BUILD_ID;
            }
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

    static bool doHook() {
        void *ptr = DobbySymbolResolver(nullptr, "__system_property_read_callback");
        if (ptr && DobbyHook(ptr, (void *)my_system_property_read_callback, (void **)&o_system_property_read_callback) == 0) {
            LOGD("Hooked __system_property_read_callback at %p", ptr);
            return true;
        }
        LOGE("Failed to hook __system_property_read_callback");
        return false;
    }

    static void doSpoofVending() {
        int requestSdk = 32;
        jclass buildVersionClass = env->FindClass("android/os/Build$VERSION");
        if (!buildVersionClass) {
            LOGE("Build.VERSION class not found");
            env->ExceptionClear();
            return;
        }
        jfieldID sdkIntFieldID = env->GetStaticFieldID(buildVersionClass, "SDK_INT", "I");
        if (!sdkIntFieldID) {
            LOGE("SDK_INT field not found");
            env->ExceptionClear();
            env->DeleteLocalRef(buildVersionClass);
            return;
        }
        int oldValue = env->GetStaticIntField(buildVersionClass, sdkIntFieldID);
        int targetSdk = std::min(oldValue, requestSdk);
        if (oldValue != targetSdk) {
            env->SetStaticIntField(buildVersionClass, sdkIntFieldID, targetSdk);
            if (env->ExceptionCheck()) {
                env->ExceptionDescribe();
                env->ExceptionClear();
                LOGE("Failed to set SDK_INT");
            } else {
                LOGD("[SDK_INT] %d -> %d", oldValue, targetSdk);
            }
        }
        env->DeleteLocalRef(buildVersionClass);
    }

    static void parsePropFile(const std::string& path) {
        propMap.clear();
        std::ifstream file(path);
        if (!file.is_open()) return;
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
        if (propMap.count("DEBUG")) {
            std::string v = propMap["DEBUG"];
            DEBUG = (v == "1" || v == "true");
            propMap.erase("DEBUG");
        }
        if (propMap.count("FINGERPRINT")) {
            std::string fingerprint = propMap["FINGERPRINT"];
            std::istringstream iss(fingerprint);
            std::string token;
            std::vector<std::string> parts;
            while (std::getline(iss, token, '/')) {
                std::istringstream subIss(token);
                std::string subToken;
                while (std::getline(subIss, subToken, ':')) {
                    parts.push_back(subToken);
                }
            }
            static const char* keys[] = {"BRAND", "PRODUCT", "DEVICE", "RELEASE", "ID", "INCREMENTAL", "TYPE", "TAGS"};
            for (size_t i = 0; i < 8; ++i) {
                propMap[keys[i]] = (i < parts.size()) ? parts[i] : "";
            }
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
                    continue;
                }
                LOGD("Set '%s' to '%s'", key.c_str(), val.c_str());
            }
        }
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

    static void injectDex() {
        jclass clClass = env->FindClass("java/lang/ClassLoader");
        jmethodID getSystemClassLoader = env->GetStaticMethodID(clClass, "getSystemClassLoader", "()Ljava/lang/ClassLoader;");
        jobject systemClassLoader = env->CallStaticObjectMethod(clClass, getSystemClassLoader);
        if (env->ExceptionCheck()) {
            env->ExceptionDescribe();
            env->ExceptionClear();
            return;
        }

        jclass dexClClass = env->FindClass("dalvik/system/PathClassLoader");
        jmethodID dexClInit = env->GetMethodID(dexClClass, "<init>", "(Ljava/lang/String;Ljava/lang/ClassLoader;)V");
        jstring classesJar = env->NewStringUTF((dir + "/classes.dex").c_str());
        jobject dexCl = env->NewObject(dexClClass, dexClInit, classesJar, systemClassLoader);
        if (env->ExceptionCheck()) {
            env->ExceptionDescribe();
            env->ExceptionClear();
            return;
        }

        jmethodID loadClass = env->GetMethodID(clClass, "loadClass", "(Ljava/lang/String;)Ljava/lang/Class;");
        jstring entryClassName = env->NewStringUTF("es.chiteroman.playintegrityfix.EntryPoint");
        jobject entryClassObj = env->CallObjectMethod(dexCl, loadClass, entryClassName);
        jclass entryPointClass = static_cast<jclass>(entryClassObj);
        if (env->ExceptionCheck()) {
            env->ExceptionDescribe();
            env->ExceptionClear();
            return;
        }

        jmethodID entryInit = env->GetStaticMethodID(entryPointClass, "init", "(Ljava/lang/String;ZZZ)V");
        jstring jsonStr = env->NewStringUTF(propMapToJson().c_str());
        env->CallStaticVoidMethod(entryPointClass, entryInit, jsonStr, spoofProvider, spoofSignature, spoofBuild);
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
    }
}

extern "C" [[gnu::visibility("default"), maybe_unused]] bool
init(JavaVM *vm, const std::string &gmsDir, bool isGmsUnstable, bool isVending) {
    PIF::isGmsUnstable = isGmsUnstable;
    PIF::isVending = isVending;

    if (vm->GetEnv(reinterpret_cast<void **>(&PIF::env), JNI_VERSION_1_6) != JNI_OK) {
        LOGE("[INJECT] JNI_ERR!");
        return true;
    }

    PIF::dir = gmsDir;
    LOGD("[INJECT] GMS dir: %s", PIF::dir.c_str());

    PIF::parsePropFile(PIF::dir + "/pif.prop");
    PIF::parseProps();

    if (PIF::isGmsUnstable) {
        if (PIF::spoofBuild) {
            PIF::UpdateBuildFields();
        }

        if (PIF::spoofProvider || PIF::spoofSignature) {
            PIF::injectDex();
        } else {
            LOGD("[INJECT] Dex file won't be injected due to spoofProvider and spoofSignature being false");
        }

        if (PIF::spoofProps) {
            return !PIF::doHook();
        }
    } else if (PIF::isVending && PIF::spoofVendingSdk) {
        PIF::doSpoofVending();
    }

    return true;
}