import { exec, spawn, toast } from "./assets/kernelsu.js";

let forcePreview = true;
let shellRunning = false;
let initialPinchDistance = null;
let currentFontSize = 14;
const MIN_FONT_SIZE = 8;
const MAX_FONT_SIZE = 24;

const spoofBuildToggle = document.getElementById('toggle-spoofBuild');
const spoofProviderToggle = document.getElementById('toggle-spoofProvider');
const spoofPropsToggle = document.getElementById('toggle-spoofProps');
const spoofSignatureToggle = document.getElementById('toggle-spoofSignature');
const debugToggle = document.getElementById('toggle-debug');
const spoofVendingSdkToggle = document.getElementById('toggle-sdk-vending');
const spoofConfig = [
    { container: "spoofBuild-toggle-container", toggle: spoofBuildToggle, type: 'spoofBuild' },
    { container: "spoofProvider-toggle-container", toggle: spoofProviderToggle, type: 'spoofProvider' },
    { container: "spoofProps-toggle-container", toggle: spoofPropsToggle, type: 'spoofProps' },
    { container: "spoofSignature-toggle-container", toggle: spoofSignatureToggle, type: 'spoofSignature' },
    { container: "debug-toggle-container", toggle: debugToggle, type: 'DEBUG' },
    { container: "sdk-vending-toggle-container", toggle: spoofVendingSdkToggle, type: 'spoofVendingSdk' }
];

// Apply button event listeners
function applyButtonEventListeners() {
    const fetchButton = document.getElementById('fetch');
    const previewFpToggle = document.getElementById('preview-fp-toggle-container');
    const advanced = document.getElementById('advanced');
    const clearButton = document.querySelector('.clear-terminal');
    const terminal = document.querySelector('.output-terminal-content');
    const githubBtn = document.getElementById('github-btn');

    fetchButton.addEventListener('click', runAction);
    previewFpToggle.addEventListener('click', async () => {
        forcePreview = !forcePreview;
        loadPreviewFingerprintConfig();
        appendToOutput(`[+] Switched fingerprint to ${forcePreview ? 'preview' : 'beta'}`);
    });

    advanced.addEventListener('click', () => {
        document.querySelectorAll('.advanced-option').forEach(option => {
            option.style.display = 'flex';
            option.offsetHeight;
            option.classList.add('advanced-show');
        });
        advanced.style.display = 'none';
        const lists = Array.from(document.querySelectorAll('.toggle-list'));
        lists.forEach(list => list.style.borderBottom = '1px solid var(--border-color)');
        const visibleLists = lists.filter(list => getComputedStyle(list).display !== 'none');
        if (visibleLists.length > 0) visibleLists[visibleLists.length - 1].style.borderBottom = 'none';
    });

    clearButton.addEventListener('click', () => {
        terminal.innerHTML = '';
        currentFontSize = 14;
        updateFontSize(currentFontSize);
    });

    terminal.addEventListener('touchstart', (e) => {
        if (e.touches.length === 2) {
            e.preventDefault();
            initialPinchDistance = getDistance(e.touches[0], e.touches[1]);
        }
    }, { passive: false });
    terminal.addEventListener('touchmove', (e) => {
        if (e.touches.length === 2) {
            e.preventDefault();
            const currentDistance = getDistance(e.touches[0], e.touches[1]);
            
            if (initialPinchDistance === null) {
                initialPinchDistance = currentDistance;
                return;
            }

            const scale = currentDistance / initialPinchDistance;
            const newFontSize = currentFontSize * scale;
            updateFontSize(newFontSize);
            initialPinchDistance = currentDistance;
        }
    }, { passive: false });
    terminal.addEventListener('touchend', () => {
        initialPinchDistance = null;
    });

    githubBtn.onclick = () => {
        const link = "https://github.com/KOWX712/PlayIntegrityFix/releases/latest";
        toast("Redirecting to " + link);
        setTimeout(() => {
            exec(`am start -a android.intent.action.VIEW -d ${link}`);
        }, 100);
    }
}

// Function to load the version from module.prop
async function loadVersionFromModuleProp() {
    const versionElement = document.getElementById('version-text');
    const { errno, stdout, stderr } = await exec("grep '^version=' /data/adb/modules/playintegrityfix/module.prop | cut -d'=' -f2");
    if (errno === 0) {
        versionElement.textContent = stdout.trim();
    } else {
        appendToOutput("[!] Failed to read version from module.prop");
        console.error("Failed to read version from module.prop:", stderr);
    }
    checkDescription();
}

// Check description
async function checkDescription() {
    const unofficialOverlay = document.getElementById('unofficial-warning');
    const { errno } = await exec("grep -q 'tampered' /data/adb/modules/playintegrityfix/module.prop");
    if (typeof ksu !== 'undefined' && errno === 0) {
        unofficialOverlay.style.display = 'flex';
    }
}

// Function to load spoof config
async function loadSpoofConfig() {
    try {
        const { errno, stdout, stderr } = await exec(`cat /data/adb/modules/playintegrityfix/pif.prop`);
        if (errno !== 0) throw new Error(stderr);

        const config = parsePropToMap(stdout);
        spoofBuildToggle.checked = config.spoofBuild;
        spoofProviderToggle.checked = config.spoofProvider;
        spoofPropsToggle.checked = config.spoofProps;
        spoofSignatureToggle.checked = config.spoofSignature;
        debugToggle.checked = config.DEBUG;
        spoofVendingSdkToggle.checked = config.spoofVendingSdk;
    } catch (error) {
        appendToOutput(`[!] Failed to load spoof config.`);
        appendToOutput('[!] Warning: Do not use third party tools to fetch pif.prop');
        resetPifProp();
        console.error(`Failed to load spoof config:`, error);
    }
}

// Reset pif.prop to default
function resetPifProp() {
    fetch('https://raw.githubusercontent.com/KOWX712/PlayIntegrityFix/inject_s/module/pif.prop')
        .then(response => {
            if (!response.ok) {
                throw new Error(`HTTP error! status: ${response.status}`);
            }
            return response.text();
        })
        .then(async text => {
            const pifProp = text.trim();
            const { errno } = await exec(`
                echo '${pifProp}' > /data/adb/modules/playintegrityfix/pif.prop
                rm -f /data/adb/pif.prop || true
            `);
            if (errno === 0) {
                appendToOutput(`[+] Successfully reset pif.prop`);
            } else {
                appendToOutput(`[!] Failed to reset pif.prop`);
            }
        })
        .catch(error => {
            appendToOutput(`[!] Failed to reset pif.prop: ${error.message}`);
        });
}

// Function to setup spoof config button
function setupSpoofConfigButton(container, toggle, type) {
    document.getElementById(container).addEventListener('click', async () => {
        if (shellRunning) return;
        muteToggle();
        const { errno, stdout, stderr } = await exec(`
            [ ! -f /data/adb/modules/playintegrityfix/pif.prop ] || echo "/data/adb/modules/playintegrityfix/pif.prop"
            [ ! -f /data/adb/pif.prop ] || echo "/data/adb/pif.prop"
        `);
        if (errno === 0) {
            const isSuccess = await updateSpoofConfig(toggle, type, stdout);
            if (isSuccess) {
                loadSpoofConfig();
                appendToOutput(`[+] ${toggle.checked ? "Disabled" : "Enabled"} ${type}`);
            } else {
                appendToOutput(`[!] Failed to ${toggle.checked ? "disable" : "enable"} ${type}`);
            }
            await exec(`
                killall com.google.android.gms.unstable || true
                killall com.android.vending || true
            `);
        } else {
            console.error(`Failed to find pif.prop:`, stderr);
        }
        unmuteToggle();
    });
}

/**
 * Update pif.prop
 * @param {HTMLInputElement} toggle - config toggle of pif.prop
 * @param {string} type - prop key to change
 * @param {string} pifFile - Path of pif.prop list
 * @returns {Promise<boolean>}
 */
async function updateSpoofConfig(toggle, type, pifFile) {
    let isSuccess = true;
    const files = pifFile.split('\n').filter(line => line.trim() !== '');
    
    for (const pifFile of files) {
        try {
            // read
            const { stdout } = await exec(`cat ${pifFile}`);
            const config = parsePropToMap(stdout);

            // update field
            config[type] = !toggle.checked;
            const prop = parseMapToProp(config);

            // write
            const { errno } = await exec(`echo '${prop}' > ${pifFile}`);
            if (errno !== 0) isSuccess = false;
        } catch (error) {
            console.error(`Failed to update ${pifFile}:`, error);
            isSuccess = false;
        }
    }
    return isSuccess;
}

// Function to load preview fingerprint config
function loadPreviewFingerprintConfig() {
    const previewFpToggle = document.getElementById('toggle-preview-fp');
    previewFpToggle.checked = forcePreview;
}

// Function to append element in output terminal
function appendToOutput(content) {
    const output = document.querySelector('.output-terminal-content');
    if (content.trim() === "") {
        const lineBreak = document.createElement('br');
        output.appendChild(lineBreak);
    } else {
        const line = document.createElement('p');
        line.className = 'output-content';
        line.innerHTML = content.replace(/ /g, '&nbsp;');
        output.appendChild(line);
    }
    output.scrollTop = output.scrollHeight;
}

// Function to run the script and display its output
function runAction() {
    if (shellRunning) return;
    muteToggle();
    const args = ["/data/adb/modules/playintegrityfix/autopif.sh"];
    if (forcePreview) args.push('-p');
    const scriptOutput = spawn("sh", args);
    scriptOutput.stdout.on('data', (data) => appendToOutput(data));
    scriptOutput.stderr.on('data', (data) => appendToOutput(data));
    scriptOutput.on('exit', () => {
        appendToOutput("");
        unmuteToggle();
    });
    scriptOutput.on('error', () => {
        appendToOutput("[!] Error: Fail to execute autopif.sh");
        appendToOutput("");
        unmuteToggle();
    });
}

function updateAutopif() {
    muteToggle();
    const scriptOutput = spawn("sh", ["/data/adb/modules/playintegrityfix/autopif_ota.sh"]);
    scriptOutput.stdout.on('data', (data) => appendToOutput(data));
    scriptOutput.stderr.on('data', (data) => appendToOutput(data));
    scriptOutput.on('exit', () => {
        unmuteToggle();
    });
    scriptOutput.on('error', () => {
        appendToOutput("[!] Error: Fail to execute autopif_ota.sh");
        appendToOutput("");
        unmuteToggle();
    });
}

function muteToggle() {
    shellRunning = true;
    document.querySelectorAll('.toggle-list').forEach(toggle => {
        toggle.classList.add('toggle-muted');
    });
}

function unmuteToggle() {
    shellRunning = false;
    document.querySelectorAll('.toggle-list').forEach(toggle => {
        toggle.classList.remove('toggle-muted');
    });
}

/**
 * Parse prop to map
 * @param {string} prop - prop string
 * @returns {Object} - map of prop
 */
function parsePropToMap(prop) {
    const map = {};
    if (!prop || typeof prop !== 'string') return map;
    const lines = prop.split(/\r?\n/);
    for (const line of lines) {
        const trimmed = line.trim();
        if (!trimmed || trimmed.startsWith('#')) continue;
        const eqIdx = trimmed.indexOf('=');
        if (eqIdx === -1) continue;
        const key = trimmed.slice(0, eqIdx).trim();
        let value = trimmed.slice(eqIdx + 1).trim();
        if (value === 'true' || value === 'false') value = value === 'true';
        else if (/^\d+$/.test(value)) value = parseInt(value, 10);
        else if (/^\d+\.\d+$/.test(value)) value = parseFloat(value);
        map[key] = value;
    }
    return map;
}

/**
 * Parse map to prop
 * @param {Object} map - map of prop
 * @returns {string} - prop string
 */
function parseMapToProp(map) {
    if (!map || typeof map !== 'object') return '';
    return Object.entries(map)
        .map(([key, value]) => {
            if (typeof value === 'boolean') return `${key}=${value ? 'true' : 'false'}`;
            return `${key}=${value}`;
        })
        .join('\n');
}

/**
 * Simulate MD3 ripple animation
 * Usage: class="ripple-element" style="position: relative; overflow: hidden;"
 * Note: Require background-color to work properly
 * @return {void}
 */
function applyRippleEffect() {
    document.querySelectorAll('.ripple-element').forEach(element => {
        if (element.dataset.rippleListener !== "true") {
            element.addEventListener("pointerdown", async (event) => {
                // Pointer up event
                const handlePointerUp = () => {
                    ripple.classList.add("end");
                    setTimeout(() => {
                        ripple.classList.remove("end");
                        ripple.remove();
                    }, duration * 1000);
                    element.removeEventListener("pointerup", handlePointerUp);
                    element.removeEventListener("pointercancel", handlePointerUp);
                };
                element.addEventListener("pointerup", handlePointerUp);
                element.addEventListener("pointercancel", handlePointerUp);

                const ripple = document.createElement("span");
                ripple.classList.add("ripple");

                // Calculate ripple size and position
                const rect = element.getBoundingClientRect();
                const width = rect.width;
                const size = Math.max(rect.width, rect.height);
                const x = event.clientX - rect.left - size / 2;
                const y = event.clientY - rect.top - size / 2;

                // Determine animation duration
                let duration = 0.2 + (width / 800) * 0.4;
                duration = Math.min(0.8, Math.max(0.2, duration));

                // Set ripple styles
                ripple.style.width = ripple.style.height = `${size}px`;
                ripple.style.left = `${x}px`;
                ripple.style.top = `${y}px`;
                ripple.style.animationDuration = `${duration}s`;
                ripple.style.transition = `opacity ${duration}s ease`;

                // Adaptive color
                const computedStyle = window.getComputedStyle(element);
                const bgColor = computedStyle.backgroundColor || "rgba(0, 0, 0, 0)";
                const isDarkColor = (color) => {
                    const rgb = color.match(/\d+/g);
                    if (!rgb) return false;
                    const [r, g, b] = rgb.map(Number);
                    return (r * 0.299 + g * 0.587 + b * 0.114) < 96; // Luma formula
                };
                ripple.style.backgroundColor = isDarkColor(bgColor) ? "rgba(255, 255, 255, 0.2)" : "";

                // Append ripple
                element.appendChild(ripple);
            });
            element.dataset.rippleListener = "true";
        }
    });
}

// Function to check if running in MMRL
async function checkMMRL() {
    if (typeof ksu !== 'undefined' && ksu.mmrl) {
        // Set status bars theme based on device theme
        try {
            $playintegrityfix.setLightStatusBars(!window.matchMedia('(prefers-color-scheme: dark)').matches)
        } catch (error) {
            console.log("Error setting status bars theme:", error)
        }
    }
}

function getDistance(touch1, touch2) {
    return Math.hypot(
        touch1.clientX - touch2.clientX,
        touch1.clientY - touch2.clientY
    );
}

function updateFontSize(newSize) {
    currentFontSize = Math.min(Math.max(newSize, MIN_FONT_SIZE), MAX_FONT_SIZE);
    const terminal = document.querySelector('.output-terminal-content');
    terminal.style.fontSize = `${currentFontSize}px`;
}

document.addEventListener('DOMContentLoaded', async () => {
    checkMMRL();
    loadVersionFromModuleProp();
    await loadSpoofConfig();
    spoofConfig.forEach(config => {
        setupSpoofConfigButton(config.container, config.toggle, config.type);
    });
    loadPreviewFingerprintConfig();
    applyButtonEventListeners();
    applyRippleEffect();
    updateAutopif();
});
