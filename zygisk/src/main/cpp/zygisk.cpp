#include "zygisk.hpp"
#include <android/log.h>
#include <string>
#include <vector>
#include <filesystem>
#include <dlfcn.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/stat.h>
#include "checksum.h"

#define LOGD(...) __android_log_print(ANDROID_LOG_DEBUG, "PIF_ALT", __VA_ARGS__)

#define DEX_PATH "/data/adb/modules/playintegrityfix/classes.dex"
#define LIB_64 "/data/adb/modules/playintegrityfix/inject/arm64-v8a.so"
#define LIB_32 "/data/adb/modules/playintegrityfix/inject/armeabi-v7a.so"
#define MODULE_PROP "/data/adb/modules/playintegrityfix/module.prop"
#define DEFAULT_PIF "/data/adb/modules/playintegrityfix/pif.prop"
#define CUSTOM_PIF "/data/adb/pif.prop"

#define VENDING_PKG "com.android.vending"
#define DROIDGUARD_PKG "com.google.android.gms.unstable"

namespace FileUtils {
    ssize_t robustRead(int fd, void* buffer, size_t count) {
        ssize_t total = 0;
        char* buf = static_cast<char*>(buffer);
        while (count > 0) {
            ssize_t ret = TEMP_FAILURE_RETRY(read(fd, buf, count));
            if (ret <= 0) return ret < 0 ? -1 : total;
            total += ret;
            buf += ret;
            count -= ret;
        }
        return total;
    }

    ssize_t robustWrite(int fd, const void* buffer, size_t count) {
        ssize_t total = 0;
        const char* buf = static_cast<const char*>(buffer);
        while (count > 0) {
            ssize_t ret = TEMP_FAILURE_RETRY(write(fd, buf, count));
            if (ret <= 0) return ret < 0 ? -1 : total;
            total += ret;
            buf += ret;
            count -= ret;
        }
        return total;
    }

    bool copy(const std::string& src, const std::string& dest, mode_t mode = 0777) {
        if (!std::filesystem::exists(src)) return false;
        bool copied = std::filesystem::copy_file(src, dest, std::filesystem::copy_options::overwrite_existing);
        return copied && (chmod(dest.c_str(), mode) == 0);
    }
}

namespace Integrity {
    uint32_t computeCRC32(const uint8_t* data, size_t length) {
        uint32_t crc = 0xFFFFFFFF;
        for (size_t i = 0; i < length; ++i) {
            crc ^= data[i];
            for (int j = 0; j < 8; ++j) {
                crc = (crc >> 1) ^ (0xEDB88320U & -(crc & 1));
            }
        }
        return ~crc;
    }

    bool checkModule(const char* path, const char* expectedHex) {
        int fd = open(path, O_RDWR);
        if (fd < 0) return false;

        std::vector<uint8_t> data;
        uint8_t buffer[512];
        ssize_t bytesRead;
        while ((bytesRead = read(fd, buffer, sizeof(buffer))) > 0) {
            data.insert(data.end(), buffer, buffer + bytesRead);
        }
        close(fd);
        if (data.empty()) return false;

        uint32_t crc = computeCRC32(data.data(), data.size());
        uint32_t expected;
        sscanf(expectedHex, "%x", &expected);
        if (crc == expected) return true;

        LOGD("[COMPANION] Module tampered detected!");
        fd = open(path, O_RDWR);
        if (fd < 0) return false;

        std::string content(data.begin(), data.end());
        std::vector<std::string> lines;
        size_t pos = 0;
        while (pos < content.size()) {
            size_t end = content.find('\n', pos);
            if (end == std::string::npos) end = content.size();
            std::string line = content.substr(pos, end - pos + 1);
            if (line.find("description=") == 0) {
                line = "description=❌ This module has been tampered, please install from official source.\n";
            }
            lines.push_back(line);
            pos = end + 1;
        }

        ftruncate(fd, 0);
        lseek(fd, 0, SEEK_SET);
        for (const auto& line : lines) {
            if (FileUtils::robustWrite(fd, line.c_str(), line.size()) != (ssize_t)line.size()) {
                close(fd);
                return false;
            }
        }
        close(fd);
        return false;
    }
}

static void handleCompanion(int fd) {
    bool success = true;
    int dirSize = 0;
    FileUtils::robustRead(fd, &dirSize, sizeof(int));

    std::string gmsDir(dirSize, '\0');
    ssize_t readBytes = FileUtils::robustRead(fd, gmsDir.data(), dirSize);
    gmsDir.resize(readBytes);

    LOGD("[COMPANION] GMS directory: %s", gmsDir.c_str());

    std::string libPath = gmsDir + "/libinject.so";
    #if defined(__aarch64__)
        success &= FileUtils::copy(LIB_64, libPath);
    #elif defined(__arm__)
        success &= FileUtils::copy(LIB_32, libPath);
    #endif
    LOGD("[COMPANION] Injected library copied");

    std::string dexPath = gmsDir + "/classes.dex";
    success &= FileUtils::copy(DEX_PATH, dexPath, 0644);
    LOGD("[COMPANION] Dex file copied");

    std::string pifPath = gmsDir + "/pif.prop";
    success &= (FileUtils::copy(CUSTOM_PIF, pifPath) || FileUtils::copy(DEFAULT_PIF, pifPath));
    LOGD("[COMPANION] PIF file copied");

    success &= Integrity::checkModule(MODULE_PROP, MODULE_PROP_CHECKSUM_HEX);
    LOGD("[COMPANION] Module.prop verified");

    FileUtils::robustWrite(fd, &success, sizeof(bool));
}

using namespace zygisk;

class IntegrityModule : public ModuleBase {
public:
    void onLoad(Api* api_, JNIEnv* env_) override {
        api = api_;
        env = env_;
    }

    void preAppSpecialize(AppSpecializeArgs* args) override {
        api->setOption(DLCLOSE_MODULE_LIBRARY);
        if (!args) return;

        if (access("/data/adb/pif_script_only", F_OK) == 0) return;

        std::string appDir, appName;
        const char* rawDir = env->GetStringUTFChars(args->app_data_dir, nullptr);
        if (rawDir) {
            appDir = rawDir;
            env->ReleaseStringUTFChars(args->app_data_dir, rawDir);
        }

        const char* rawName = env->GetStringUTFChars(args->nice_name, nullptr);
        if (rawName) {
            appName = rawName;
            env->ReleaseStringUTFChars(args->nice_name, rawName);
        }

        bool isGms = appDir.ends_with("/com.google.android.gms") || appDir.ends_with("/com.android.vending");
        if (!isGms) return;

        api->setOption(FORCE_DENYLIST_UNMOUNT);

        gmsUnstable = (appName == DROIDGUARD_PKG);
        vending = (appName == VENDING_PKG);
        if (!gmsUnstable && !vending) {
            api->setOption(DLCLOSE_MODULE_LIBRARY);
            return;
        }

        int fd = api->connectCompanion();
        int size = static_cast<int>(appDir.size());
        FileUtils::robustWrite(fd, &size, sizeof(int));
        FileUtils::robustWrite(fd, appDir.data(), size);

        bool result = false;
        FileUtils::robustRead(fd, &result, sizeof(bool));
        close(fd);

        if (result) targetDir = appDir;
    }

    void postAppSpecialize(const AppSpecializeArgs*) override {
        if (targetDir.empty()) return;

        std::string libPath = targetDir + "/libinject.so";
        void* libHandle = dlopen(libPath.c_str(), RTLD_NOW);
        if (!libHandle) return;

        typedef bool (*InitFunc)(JavaVM*, const std::string&, bool, bool);
        auto init = reinterpret_cast<InitFunc>(dlsym(libHandle, "init"));

        JavaVM* vm = nullptr;
        env->GetJavaVM(&vm);

        if (init(vm, targetDir, gmsUnstable, vending)) {
            LOGD("Closing injected library");
            dlclose(libHandle);
        }
    }

    void preServerSpecialize(ServerSpecializeArgs*) override {
        api->setOption(DLCLOSE_MODULE_LIBRARY);
    }

private:
    Api* api = nullptr;
    JNIEnv* env = nullptr;
    std::string targetDir;
    bool gmsUnstable = false;
    bool vending = false;
};

REGISTER_ZYGISK_MODULE(IntegrityModule)
REGISTER_ZYGISK_COMPANION(handleCompanion)