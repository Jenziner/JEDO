// ============================================================================
// JEDO Gateway Console - Feature 3: Gens-Verwaltung
// ============================================================================

// === Gateway Configuration ===

const GATEWAY_CONFIG = {
    STORAGE_KEY: 'jedo_gateway_url',
    DEFAULT_URL: 'https://localhost:53901'
};

/**
 * Lädt Gateway-URL aus LocalStorage
 * @returns {string} Gateway-URL
 */
function loadGatewayUrl() {
    try {
        const storedUrl = localStorage.getItem(GATEWAY_CONFIG.STORAGE_KEY);
        return storedUrl || GATEWAY_CONFIG.DEFAULT_URL;
    } catch (error) {
        console.error('Error loading gateway URL from localStorage:', error);
        return GATEWAY_CONFIG.DEFAULT_URL;
    }
}

/**
 * Speichert Gateway-URL in LocalStorage
 * @param {string} url - Zu speichernde URL
 * @returns {boolean} Erfolg der Operation
 */
function saveGatewayUrl(url) {
    try {
        localStorage.setItem(GATEWAY_CONFIG.STORAGE_KEY, url);
        return true;
    } catch (error) {
        if (error.name === 'QuotaExceededError') {
            console.error('LocalStorage quota exceeded. Unable to save gateway URL.');
        } else {
            console.error('Error saving gateway URL to localStorage:', error);
        }
        return false;
    }
}

/**
 * Validiert Gateway-URL
 * @param {string} url - Zu validierende URL
 * @returns {Object} Validierungsresultat mit success und message
 */
function validateGatewayUrl(url) {
    url = url.trim();

    if (!url) {
        return { success: false, message: 'URL darf nicht leer sein.' };
    }

    if (!url.startsWith('http://') && !url.startsWith('https://')) {
        return { success: false, message: 'URL muss mit http:// oder https:// beginnen.' };
    }

    try {
        new URL(url);
        return { success: true, message: 'URL ist gültig.' };
    } catch (error) {
        return { success: false, message: 'Ungültiges URL-Format.' };
    }
}

/**
 * Zeigt Feedback-Nachricht an
 * @param {string} message - Nachricht
 * @param {boolean} isSuccess - Erfolg oder Fehler
 */
function showFeedback(message, isSuccess = true) {
    const feedbackElement = document.getElementById('save-feedback');
    const inputElement = document.getElementById('gateway-url');

    feedbackElement.textContent = message;
    feedbackElement.style.color = isSuccess ? 'var(--color-success)' : '#e74c3c';
    feedbackElement.classList.add('show');

    if (isSuccess) {
        inputElement.classList.add('success-flash');
        setTimeout(() => {
            inputElement.classList.remove('success-flash');
        }, 600);
    }

    setTimeout(() => {
        feedbackElement.classList.remove('show');
    }, 3000);
}

/**
 * Handler für Gateway-URL-Speicherung
 */
function handleSaveGatewayUrl() {
    const inputElement = document.getElementById('gateway-url');
    const url = inputElement.value;

    const validation = validateGatewayUrl(url);
    
    if (!validation.success) {
        showFeedback(validation.message, false);
        return;
    }

    const success = saveGatewayUrl(url);
    
    if (success) {
        showFeedback('✓ Gateway-URL erfolgreich gespeichert!', true);
        console.log('Gateway URL saved:', url);
    } else {
        showFeedback('Fehler beim Speichern der URL.', false);
    }
}

/**
 * Gibt die aktuelle Gateway-URL zurück
 * @returns {string} Aktuelle Gateway-URL
 */
function getGatewayUrl() {
    return document.getElementById('gateway-url').value.trim();
}

// === State Management ===

const appState = {
    columns: [],
    counters: {
        ager: 1,
        gens: 0,
        human: 0
    }
};

// === State Helper Functions ===

/**
 * Gibt alle Spalten zurück
 * @returns {Array} Array aller Column-Objekte
 */
function getAllColumns() {
    return appState.columns;
}

/**
 * Gibt eine bestimmte Spalte zurück
 * @param {string} columnId - ID der Spalte
 * @returns {Object|null} Column-Objekt oder null
 */
function getColumnById(columnId) {
    return appState.columns.find(col => col.id === columnId) || null;
}

/**
 * Gibt alle Spalten eines bestimmten Typs zurück
 * @param {string} type - Column-Typ (ager, gens, human)
 * @returns {Array} Array von Column-Objekten
 */
function getColumnsByType(type) {
    return appState.columns.filter(col => col.type === type);
}

/**
 * Setzt den State einer Spalte
 * @param {string} columnId - ID der Spalte
 * @param {string} newState - Neuer State (NOT_LOADED, LOADED, REGISTERED, ENROLLED)
 * @returns {boolean} Erfolg der Operation
 */
function setColumnState(columnId, newState) {
    const validStates = ['NOT_LOADED', 'LOADED', 'REGISTERED', 'ENROLLED'];
    
    if (!validStates.includes(newState)) {
        console.error(`Invalid state: ${newState}. Must be one of ${validStates.join(', ')}`);
        return false;
    }

    const column = getColumnById(columnId);
    if (!column) {
        console.error(`Column ${columnId} not found.`);
        return false;
    }

    const oldState = column.state;
    column.state = newState;
    
    console.log(`Column ${columnId} state changed: ${oldState} → ${newState}`);
    
    triggerStateUpdate(columnId, newState);
    
    return true;
}

/**
 * Gibt den State einer Spalte zurück
 * @param {string} columnId - ID der Spalte
 * @returns {string|null} State oder null
 */
function getColumnState(columnId) {
    const column = getColumnById(columnId);
    return column ? column.state : null;
}

/**
 * Aktualisiert die Data-Struktur einer Spalte
 * @param {string} columnId - ID der Spalte
 * @param {Object} newData - Zu mergende Daten
 * @returns {boolean} Erfolg der Operation
 */
function updateColumnData(columnId, newData) {
    const column = getColumnById(columnId);
    if (!column) {
        console.error(`Column ${columnId} not found.`);
        return false;
    }

    column.data = { ...column.data, ...newData };
    
    console.log(`Column ${columnId} data updated:`, column.data);
    return true;
}

/**
 * Gibt die Daten einer Spalte zurück
 * @param {string} columnId - ID der Spalte
 * @returns {Object|null} Data-Objekt oder null
 */
function getColumnData(columnId) {
    const column = getColumnById(columnId);
    return column ? column.data : null;
}

/**
 * Triggert State-Update-Event
 * @param {string} columnId - ID der Spalte
 * @param {string} newState - Neuer State
 */
function triggerStateUpdate(columnId, newState) {
    const event = new CustomEvent('columnStateChanged', {
        detail: { columnId, newState }
    });
    document.dispatchEvent(event);
}

/**
 * Exportiert den kompletten App-State
 * @returns {Object} Kopie des App-States
 */
function exportState() {
    return JSON.parse(JSON.stringify(appState));
}

/**
 * Importiert State
 * @param {Object} state - Zu importierender State
 */
function importState(state) {
    if (!state.columns || !state.counters) {
        console.error('Invalid state structure.');
        return false;
    }
    
    appState.columns = state.columns;
    appState.counters = state.counters;
    
    console.log('State imported:', appState);
    return true;
}

/**
 * Gibt den aktuellen State in der Konsole aus
 */
function debugState() {
    console.group('🔍 JEDO App State');
    console.log('Gateway URL:', getGatewayUrl());
    console.log('Columns:', appState.columns);
    console.log('Counters:', appState.counters);
    console.groupEnd();
}

window.debugState = debugState;

/**
 * Parsed CN-String in Username und Affiliation
 * Pattern: username.ager.regnum.orbis.env
 * Affiliation: orbis.regnum.ager (ohne username und env!)
 * 
 * Beispiel:
 * CN: admin.alps.ea.jedo.dev
 * Parts: [username='admin', ager='alps', regnum='ea', orbis='jedo', env='dev']
 * Affiliation: orbis.regnum.ager = 'jedo.ea.alps'
 * 
 * @param {string} cn - Common Name (z.B. "admin.alps.ea.jedo.dev")
 * @returns {Object} {username, affiliation}
 */
function parseCnToUserAndAffiliation(cn) {
    if (!cn || typeof cn !== 'string') {
        return { username: null, affiliation: null };
    }

    const parts = cn.split('.');
    
    if (parts.length < 4) {
        console.warn(`⚠️ CN format too short: ${cn} (expected at least 4 parts)`);
        return { 
            username: parts[0] || null, 
            affiliation: null 
        };
    }
    
    if (parts.length === 5) {
        // Standard Ager case: username.ager.regnum.orbis.env
        // Example: ['admin', 'alps', 'ea', 'jedo', 'dev']
        const username = parts[0];  // 'admin'
        const ager = parts[1];      // 'alps'
        const regnum = parts[2];    // 'ea'
        const orbis = parts[3];     // 'jedo'
        const env = parts[4];       // 'dev' (ignored)
        
        // Affiliation = orbis.regnum.ager (NO username!)
        const affiliation = `${orbis}.${regnum}.${ager}`;
        
        console.log('🔍 CN Parsing (5 parts - Ager):', {
            input: cn,
            username: username,
            affiliation: affiliation,
            breakdown: { username, ager, regnum, orbis, env }
        });
        
        return { username, affiliation };
    }
    
    if (parts.length === 4) {
        // Possible Gens case: username.ager.regnum.orbis (no env)
        // Example: ['perplexity', 'alps', 'ea', 'jedo']
        const username = parts[0];  // 'perplexity'
        const ager = parts[1];      // 'alps'
        const regnum = parts[2];    // 'ea'
        const orbis = parts[3];     // 'jedo'
        
        // Affiliation = orbis.regnum.ager
        const affiliation = `${orbis}.${regnum}.${ager}`;
        
        console.log('🔍 CN Parsing (4 parts):', {
            input: cn,
            username: username,
            affiliation: affiliation,
            breakdown: { username, ager, regnum, orbis }
        });
        
        return { username, affiliation };
    }
    
    // Fallback for unexpected formats
    console.warn(`⚠️ Unexpected CN format: ${cn} (${parts.length} parts)`);
    const username = parts[0];
    // Try to extract affiliation from remaining parts (skip last = env, skip first = username)
    const middle = parts.slice(1, -1);
    if (middle.length >= 3) {
        // Take last 3 parts and reverse: ager, regnum, orbis → orbis, regnum, ager
        const relevant = middle.slice(-3);
        const affiliation = `${relevant[2]}.${relevant[1]}.${relevant[0]}`;
        
        console.log('🔍 CN Parsing (fallback):', {
            input: cn,
            username: username,
            affiliation: affiliation
        });
        
        return { username, affiliation };
    }
    
    return { username, affiliation: null };
}



/**
 * Extrahiert CN aus PEM-Zertifikat mittels jsrsasign
 * @param {string} pemString - PEM-formatiertes Zertifikat
 * @returns {string|null} CN oder null bei Fehler
 */
function extractCnFromCert(pemString) {
    try {
        const x509 = new X509();
        x509.readCertPEM(pemString);
        
        const subjectString = x509.getSubjectString();
        
        const cnMatch = subjectString.match(/\/CN=([^\/]+)/);
        
        if (cnMatch && cnMatch[1]) {
            return cnMatch[1];
        }
        
        return null;
    } catch (error) {
        console.error('Error parsing certificate:', error);
        return null;
    }
}

/**
 * Handler für Ager-Cert-Upload
 * @param {Event} event - File Input Change Event
 */
function handleAgerCertUpload(event) {
    const file = event.target.files[0];
    
    if (!file) {
        return;
    }

    const reader = new FileReader();
    
    reader.onload = function(e) {
        const pemContent = e.target.result;
        
        const cn = extractCnFromCert(pemContent);
        
        if (!cn) {
            showFeedback('❌ Could not extract CN from certificate', false);
            return;
        }

        const { username, affiliation } = parseCnToUserAndAffiliation(cn);

        updateColumnData('ager-1', {
            certPem: pemContent,
            cn: cn,
            username: username,
            affiliation: affiliation
        });

        document.getElementById('ager-cert-status').textContent = `✓ ${file.name}`;
        document.getElementById('ager-cert-status').classList.add('success');
        document.getElementById('ager-cn-display').textContent = cn;
        document.getElementById('ager-username-display').textContent = username || '–';
        document.getElementById('ager-affiliation-display').textContent = affiliation || '–';

        document.getElementById('ager-validate-btn').disabled = false;

        checkAgerLoadedState();

        console.log('✅ Ager certificate uploaded:', { cn, username, affiliation });
    };

    reader.onerror = function() {
        showFeedback('❌ Error reading certificate file', false);
    };

    reader.readAsText(file);
}

/**
 * Handler für Ager-Key-Upload
 * @param {Event} event - File Input Change Event
 */
function handleAgerKeyUpload(event) {
    const file = event.target.files[0];
    
    if (!file) {
        return;
    }

    const reader = new FileReader();
    
    reader.onload = function(e) {
        const keyContent = e.target.result;
        
        if (!keyContent.includes('BEGIN') || !keyContent.includes('PRIVATE KEY')) {
            showFeedback('❌ Invalid private key format (PEM expected)', false);
            return;
        }

        updateColumnData('ager-1', {
            keyPem: keyContent
        });

        document.getElementById('ager-key-status').textContent = `✓ ${file.name}`;
        document.getElementById('ager-key-status').classList.add('success');

        checkAgerLoadedState();

        console.log('✅ Ager private key uploaded');
    };

    reader.onerror = function() {
        showFeedback('❌ Error reading key file', false);
    };

    reader.readAsText(file);
}

/**
 * Prüft ob Cert + Key vorhanden sind und setzt State auf LOADED
 */
function checkAgerLoadedState() {
    const agerData = getColumnData('ager-1');
    
    if (agerData.certPem && agerData.keyPem) {
        setColumnState('ager-1', 'LOADED');
        
        document.getElementById('ager-loaded-badge').style.display = 'block';
        
        console.log('✅ Ager fully loaded (Cert + Key present)');
    }
}

/**
 * Validiert das Ager-Zertifikat
 */
function validateAgerCert() {
    const agerData = getColumnData('ager-1');
    const validationBadge = document.getElementById('ager-validation-badge');
    const validateBtn = document.getElementById('ager-validate-btn');

    if (!agerData || !agerData.certPem) {
        updateColumnData('ager-1', { isValid: false, validUntil: null });
        validationBadge.style.display = 'none';
        return;
    }

    try {
        const x509 = new X509();
        x509.readCertPEM(agerData.certPem);

        const subject = x509.getSubjectString();
        const issuer = x509.getIssuerString();
        const notBefore = x509.getNotBefore();
        const notAfter = x509.getNotAfter();

        const now = new Date();
        const isExpired = now > new Date(notAfter);

        if (isExpired) {
            updateColumnData('ager-1', { isValid: false, validUntil: notAfter });
            validateBtn.title = 'Certificate expired';
            
            validationBadge.textContent = `⚠️ Certificate expired on ${notAfter}`;
            validationBadge.className = 'status-badge badge-warning';
            validationBadge.style.display = 'block';
            return;
        }

        if (!agerData.cn) {
            updateColumnData('ager-1', { isValid: false, validUntil: null });
            
            validationBadge.textContent = '❌ No CN found in certificate';
            validationBadge.className = 'status-badge badge-error';
            validationBadge.style.display = 'block';
            return;
        }

        updateColumnData('ager-1', { isValid: true, validUntil: notAfter });
        validateBtn.title = 'Certificate valid';

        validationBadge.textContent = `✅ Ager validated until ${notAfter}`;
        validationBadge.className = 'status-badge badge-success';
        validationBadge.style.display = 'block';

        console.log('✅ Certificate validated successfully', {
            subject,
            issuer,
            notBefore,
            notAfter,
            cn: agerData.cn
        });

    } catch (error) {
        updateColumnData('ager-1', { isValid: false, validUntil: null });
        
        validationBadge.textContent = `❌ Validation failed: ${error.message}`;
        validationBadge.className = 'status-badge badge-error';
        validationBadge.style.display = 'block';
        
        console.error('Certificate validation failed:', error);
    }
}

// === Gens Management ===

/**
 * Generiert ein sicheres zufälliges Passwort
 * @param {number} length - Länge des Passworts
 * @returns {string} Generiertes Passwort
 */
function generateSecurePassword(length = 16) {
    const lowercase = 'abcdefghijklmnopqrstuvwxyz';
    const uppercase = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    const numbers = '0123456789';
    const special = '!@#$%^&*-_=+';
    const charset = lowercase + uppercase + numbers + special;
    
    let password = '';
    const array = new Uint32Array(length);
    window.crypto.getRandomValues(array);
    
    for (let i = 0; i < length; i++) {
        password += charset[array[i] % charset.length];
    }
    
    // Ensure at least one of each type
    if (!/[a-z]/.test(password)) password = password.slice(0, -1) + lowercase[Math.floor(Math.random() * lowercase.length)];
    if (!/[A-Z]/.test(password)) password = password.slice(0, -1) + uppercase[Math.floor(Math.random() * uppercase.length)];
    if (!/[0-9]/.test(password)) password = password.slice(0, -1) + numbers[Math.floor(Math.random() * numbers.length)];
    if (!/[!@#$%^&*\-_=+]/.test(password)) password = password.slice(0, -1) + special[Math.floor(Math.random() * special.length)];
    
    return password;
}

/**
 * Generiert QR-Code für Gens-Registrierung
 * @param {string} columnId - ID der Gens-Spalte
 */
function generateGensQrCode(columnId) {
    const nameInput = document.getElementById(`${columnId}-name-input`);
    const name = nameInput.value.trim();
    
    if (!name) {
        showFeedback('❌ Please enter a Gens name', false);
        return;
    }
    
    // Validate name (alphanumeric + dash/underscore)
    if (!/^[a-zA-Z0-9_-]+$/.test(name)) {
        showFeedback('❌ Name can only contain letters, numbers, dash and underscore', false);
        return;
    }
    
    // Check if Ager is loaded
    const agerData = getColumnData('ager-1');
    if (!agerData || !agerData.affiliation) {
        showFeedback('❌ Please load Ager certificate first', false);
        return;
    }
    
    // Generate username and password
    const username = `${name}.${agerData.affiliation}`;
    const password = generateSecurePassword(16);
    
    // Create QR data
    const qrData = JSON.stringify({ username, password });
    
    // Update Gens state
    updateColumnData(columnId, {
        name: name,
        username: username,
        password: password,
        qrCodeData: qrData
    });
    
    // Display QR Code
    const qrContainer = document.getElementById(`${columnId}-qr-container`);
    qrContainer.innerHTML = ''; // Clear previous QR
    
    new QRCode(qrContainer, {
        text: qrData,
        width: 200,
        height: 200,
        colorDark: '#000000',
        colorLight: '#ffffff',
        correctLevel: QRCode.CorrectLevel.M
    });
    
    // Display JSON text
    document.getElementById(`${columnId}-qr-text`).textContent = qrData;
    document.getElementById(`${columnId}-qr-display`).style.display = 'block';
    
    console.log(`✅ QR Code generated for ${username}`);
}

/**
 * Registriert einen Gens via Gateway (als Ager) - DEBUG VERSION
 */
async function registerGensViaAger() {
    const qrInput = document.getElementById('ager-qr-input');
    const successDiv = document.getElementById('ager-register-success');
    const errorDiv = document.getElementById('ager-register-error');
    
    successDiv.style.display = 'none';
    errorDiv.style.display = 'none';
    
    let qrData;
    try {
        qrData = JSON.parse(qrInput.value.trim());
    } catch (error) {
        errorDiv.textContent = '❌ Invalid JSON format';
        errorDiv.style.display = 'block';
        return;
    }
    
    if (!qrData.username || !qrData.password) {
        errorDiv.textContent = '❌ Missing username or password in QR data';
        errorDiv.style.display = 'block';
        return;
    }
    
    const agerData = getColumnData('ager-1');
    if (!agerData || !agerData.certPem || !agerData.keyPem) {
        showFeedback('❌ Please load Ager certificate and key first', false);
        return;
    }
    
    // === DEBUG: Certificate Analysis ===
    console.group('🔍 DEBUG: Certificate Analysis');
    console.log('Ager CN:', agerData.cn);
    console.log('Ager Username:', agerData.username);
    console.log('Ager Affiliation:', agerData.affiliation);
    console.log('Gens Username:', qrData.username);
    console.log('Gens Password Length:', qrData.password.length);
    
    // Check certificate format
    const certLines = agerData.certPem.split('\n');
    console.log('Certificate lines:', certLines.length);
    console.log('First line:', certLines[0]);
    console.log('Last line:', certLines[certLines.length - 1] || certLines[certLines.length - 2]);
    
    const keyLines = agerData.keyPem.split('\n');
    console.log('Key lines:', keyLines.length);
    console.log('Key first line:', keyLines[0]);
    console.groupEnd();
    
    // Build payload
    const payload = {
        certificate: agerData.certPem,
        privateKey: agerData.keyPem,
        username: qrData.username,
        secret: qrData.password,
        role: "gens",
        affiliation: agerData.affiliation,
        attrs: [
            { role: "gens" },
            { "hf.Registrar.Roles": "client" },
            { "hf.Registrar.Attributes": "*" },
            { "hf.Revoker": "false" }
        ]
    };
    
    const gatewayUrl = getGatewayUrl();
    const endpoint = `${gatewayUrl}/api/v1/ca/certificates/register`;
    
    // === DEBUG: Payload Analysis ===
    console.group('📦 DEBUG: Payload Analysis');
    console.log('Gateway URL:', gatewayUrl);
    console.log('Endpoint:', endpoint);
    console.log('Payload structure:', Object.keys(payload));
    console.log('Username:', payload.username);
    console.log('Secret:', payload.secret);
    console.log('Role:', payload.role);
    console.log('Affiliation:', payload.affiliation);
    console.log('Attrs:', payload.attrs);
    console.log('Certificate starts with:', payload.certificate.substring(0, 50));
    console.log('Certificate ends with:', payload.certificate.substring(payload.certificate.length - 50));
    console.log('Key starts with:', payload.privateKey.substring(0, 50));
    
    // Convert to JSON and analyze
    const jsonPayload = JSON.stringify(payload);
    console.log('JSON Payload Length:', jsonPayload.length);
    console.log('JSON Sample (first 500 chars):', jsonPayload.substring(0, 500));
    
    // Check for problematic characters
    const hasCarriageReturn = /\r/.test(agerData.certPem);
    const hasWindowsLineEndings = /\r\n/.test(agerData.certPem);
    console.log('Has carriage return (\\r):', hasCarriageReturn);
    console.log('Has Windows line endings (\\r\\n):', hasWindowsLineEndings);
    console.groupEnd();
    
    console.log('📤 Sending registration request...');
    
    try {
        const response = await fetch(endpoint, {
            method: 'POST',
            mode: 'cors',
            headers: {
                'Content-Type': 'application/json'
            },
            body: jsonPayload
        });
        
        // === DEBUG: Response Analysis ===
        console.group('📨 DEBUG: Response Analysis');
        console.log('Status:', response.status);
        console.log('Status Text:', response.statusText);
        console.log('Headers:', Object.fromEntries([...response.headers.entries()]));
        console.groupEnd();
        
        const result = await response.json();
        console.log('Response Body:', result);
        
        if (response.ok) {
            successDiv.style.display = 'block';
            
            const gensColumn = appState.columns.find(col => 
                col.type === 'gens' && col.data.username === qrData.username
            );
            
            if (gensColumn) {
                setColumnState(gensColumn.id, 'REGISTERED');
                
                const badge = document.getElementById(`${gensColumn.id}-registered-badge`);
                if (badge) badge.style.display = 'block';
                
                const enrollBtn = document.getElementById(`${gensColumn.id}-enroll-btn`);
                if (enrollBtn) enrollBtn.disabled = false;
            }
            
            console.log('✅ Gens registered successfully');
        } else {
            errorDiv.innerHTML = `<pre>${JSON.stringify(result, null, 2)}</pre>`;
            errorDiv.style.display = 'block';
            console.error('❌ Registration failed:', result);
        }
    } catch (error) {
        console.error('❌ Registration error:', error);
        errorDiv.textContent = `❌ Network error: ${error.message}`;
        errorDiv.style.display = 'block';
    }
}


/**
 * Führt Enrollment für Gens durch
 * @param {string} columnId - Gens Column ID
 */
async function enrollGens(columnId) {
    const gensData = getColumnData(columnId);
    const errorDiv = document.getElementById(`${columnId}-enroll-error`);
    const resultDiv = document.getElementById(`${columnId}-enroll-result`);
    const enrollBtn = document.getElementById(`${columnId}-enroll-btn`);
    
    // Reset
    errorDiv.style.display = 'none';
    
    if (!gensData || !gensData.username || !gensData.password) {
        errorDiv.textContent = '❌ Missing username or password. Generate QR code first.';
        errorDiv.style.display = 'block';
        return;
    }
    
    if (getColumnState(columnId) !== 'REGISTERED') {
        errorDiv.textContent = '❌ Gens must be registered first (via Ager)';
        errorDiv.style.display = 'block';
        return;
    }
    
    // Build payload (TEST 6 structure)
    const payload = {
        username: gensData.username,
        secret: gensData.password,
        enrollmentType: "x509",
        role: "gens"
    };
    
    console.log('📤 Enrolling Gens:', gensData.username);
    enrollBtn.disabled = true;
    enrollBtn.textContent = 'Enrolling...';
    
    try {
        const gatewayUrl = getGatewayUrl();
        const response = await fetch(`${gatewayUrl}/api/v1/ca/certificates/enroll`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(payload)
        });
        
        const result = await response.json();
        
        if (response.ok && result.data) {
            const { certificate, privateKey, rootCertificate } = result.data;
            
            // Extract CN from certificate
            const cn = extractCnFromCert(certificate);
            
            // Update state
            updateColumnData(columnId, {
                certPem: certificate,
                keyPem: privateKey,
                caCertPem: rootCertificate,
                cn: cn
            });
            
            setColumnState(columnId, 'ENROLLED');
            
            // Update UI
            document.getElementById(`${columnId}-enrolled-cn`).textContent = cn || 'N/A';
            resultDiv.style.display = 'block';
            
            // Show badges
            document.getElementById(`${columnId}-enrolled-badge`).style.display = 'block';
            
            // Setup download buttons
            setupGensDownloads(columnId);
            
            enrollBtn.textContent = '✅ Enrolled';
            
            console.log('✅ Gens enrolled successfully');
        } else {
            errorDiv.innerHTML = `<pre>${JSON.stringify(result, null, 2)}</pre>`;
            errorDiv.style.display = 'block';
            enrollBtn.disabled = false;
            enrollBtn.textContent = 'Perform Enrollment';
            console.error('❌ Enrollment failed:', result);
        }
    } catch (error) {
        errorDiv.textContent = `❌ Network error: ${error.message}`;
        errorDiv.style.display = 'block';
        enrollBtn.disabled = false;
        enrollBtn.textContent = 'Perform Enrollment';
        console.error('❌ Enrollment error:', error);
    }
}

/**
 * Erstellt Download-Link für File
 * @param {string} content - File-Inhalt
 * @param {string} filename - Dateiname
 */
function downloadFile(content, filename) {
    const blob = new Blob([content], { type: 'text/plain' });
    const url = window.URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = filename;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    window.URL.revokeObjectURL(url);
}

/**
 * Setup Download-Buttons für Gens-Zertifikate
 * @param {string} columnId - Gens Column ID
 */
function setupGensDownloads(columnId) {
    const gensData = getColumnData(columnId);
    
    if (!gensData || !gensData.certPem) return;
    
    const username = gensData.username || 'gens';
    
    // Cert Download
    const certBtn = document.getElementById(`${columnId}-download-cert`);
    certBtn.style.display = 'block';
    certBtn.onclick = () => {
        downloadFile(gensData.certPem, `${username}-cert.pem`);
        console.log(`📥 Downloaded ${username}-cert.pem`);
    };
    
    // Key Download
    const keyBtn = document.getElementById(`${columnId}-download-key`);
    keyBtn.style.display = 'block';
    keyBtn.onclick = () => {
        downloadFile(gensData.keyPem, `${username}-key.pem`);
        console.log(`📥 Downloaded ${username}-key.pem`);
    };
    
    // CA Cert Download
    const caBtn = document.getElementById(`${columnId}-download-ca`);
    caBtn.style.display = 'block';
    caBtn.onclick = () => {
        downloadFile(gensData.caCertPem, `${username}-ca-cert.pem`);
        console.log(`📥 Downloaded ${username}-ca-cert.pem`);
    };
}

/**
 * Handler für Gens Cert Upload (Loading)
 * @param {string} columnId - Gens Column ID
 * @param {Event} event - File Input Event
 */
function handleGensCertUpload(columnId, event) {
    const file = event.target.files[0];
    if (!file) return;
    
    const reader = new FileReader();
    reader.onload = function(e) {
        const pemContent = e.target.result;
        
        updateColumnData(columnId, { certPem: pemContent });
        
        document.getElementById(`${columnId}-cert-status`).textContent = `✓ ${file.name}`;
        document.getElementById(`${columnId}-cert-status`).classList.add('success');
        
        checkGensLoadedState(columnId);
        
        console.log(`✅ Gens cert uploaded for ${columnId}`);
    };
    reader.readAsText(file);
}

/**
 * Handler für Gens Key Upload (Loading)
 * @param {string} columnId - Gens Column ID
 * @param {Event} event - File Input Event
 */
function handleGensKeyUpload(columnId, event) {
    const file = event.target.files[0];
    if (!file) return;
    
    const reader = new FileReader();
    reader.onload = function(e) {
        const keyContent = e.target.result;
        
        updateColumnData(columnId, { keyPem: keyContent });
        
        document.getElementById(`${columnId}-key-status`).textContent = `✓ ${file.name}`;
        document.getElementById(`${columnId}-key-status`).classList.add('success');
        
        checkGensLoadedState(columnId);
        
        console.log(`✅ Gens key uploaded for ${columnId}`);
    };
    reader.readAsText(file);
}

/**
 * Handler für Gens CA Cert Upload (Loading)
 * @param {string} columnId - Gens Column ID
 * @param {Event} event - File Input Event
 */
function handleGensCaUpload(columnId, event) {
    const file = event.target.files[0];
    if (!file) return;
    
    const reader = new FileReader();
    reader.onload = function(e) {
        const caContent = e.target.result;
        
        updateColumnData(columnId, { caCertPem: caContent });
        
        document.getElementById(`${columnId}-ca-status`).textContent = `✓ ${file.name}`;
        document.getElementById(`${columnId}-ca-status`).classList.add('success');
        
        checkGensLoadedState(columnId);
        
        console.log(`✅ Gens CA cert uploaded for ${columnId}`);
    };
    reader.readAsText(file);
}

/**
 * Prüft ob alle 3 Gens-Certs geladen sind
 * @param {string} columnId - Gens Column ID
 */
function checkGensLoadedState(columnId) {
    const gensData = getColumnData(columnId);
    
    if (gensData.certPem && gensData.keyPem && gensData.caCertPem) {
        // Extract CN
        const cn = extractCnFromCert(gensData.certPem);
        
        updateColumnData(columnId, { cn: cn });
        
        // Update UI
        document.getElementById(`${columnId}-cn-display`).textContent = cn || 'N/A';
        document.getElementById(`${columnId}-loaded-info`).style.display = 'block';
        document.getElementById(`${columnId}-validate-btn`).disabled = false;
        
        // Set state to ENROLLED
        setColumnState(columnId, 'ENROLLED');
        
        // Show badge
        document.getElementById(`${columnId}-enrolled-badge`).style.display = 'block';
        
        console.log(`✅ Gens ${columnId} fully loaded from files`);
    }
}

/**
 * Validiert Gens-Zertifikat
 * @param {string} columnId - Gens Column ID
 */
function validateGensCert(columnId) {
    const gensData = getColumnData(columnId);
    const validationBadge = document.getElementById(`${columnId}-validation-badge`);
    
    if (!gensData || !gensData.certPem) {
        validationBadge.textContent = '❌ No certificate loaded';
        validationBadge.className = 'status-badge badge-error';
        validationBadge.style.display = 'block';
        return;
    }
    
    try {
        const x509 = new X509();
        x509.readCertPEM(gensData.certPem);
        
        const notAfter = x509.getNotAfter();
        const now = new Date();
        const isExpired = now > new Date(notAfter);
        
        if (isExpired) {
            validationBadge.textContent = `⚠️ Certificate expired on ${notAfter}`;
            validationBadge.className = 'status-badge badge-warning';
            validationBadge.style.display = 'block';
            updateColumnData(columnId, { isValid: false, validUntil: notAfter });
            return;
        }
        
        validationBadge.textContent = `✅ Gens validated until ${notAfter}`;
        validationBadge.className = 'status-badge badge-success';
        validationBadge.style.display = 'block';
        updateColumnData(columnId, { isValid: true, validUntil: notAfter });
        
        console.log(`✅ Gens certificate validated for ${columnId}`);
    } catch (error) {
        validationBadge.textContent = `❌ Validation failed: ${error.message}`;
        validationBadge.className = 'status-badge badge-error';
        validationBadge.style.display = 'block';
        updateColumnData(columnId, { isValid: false });
        console.error('Validation error:', error);
    }
}

// === Column Management Functions ===

/**
 * Erstellt eine neue Spalte und fügt sie dem DOM hinzu
 * @param {string} type - 'gens' oder 'human'
 */
function addColumn(type) {
    if (type !== 'gens' && type !== 'human') {
        console.error('Invalid column type. Must be "gens" or "human".');
        return;
    }

    appState.counters[type]++;
    const columnId = `${type}-${appState.counters[type]}`;

    const columnData = {
        id: columnId,
        type: type,
        state: 'NOT_LOADED',
        data: {}
    };

    appState.columns.push(columnData);

    const columnElement = createColumnElement(columnData);

    const container = document.getElementById('columns-container');
    container.appendChild(columnElement);

    initializeAccordions(columnElement);
    
    // Attach event listeners for Gens columns
    if (type === 'gens') {
        attachGensEventListeners(columnId);
    }

    console.log(`Column ${columnId} added. Current state:`, appState);
}

/**
 * Fügt Event-Listener für Gens-Spalte hinzu
 * @param {string} columnId - Gens Column ID
 */
function attachGensEventListeners(columnId) {
    // Loading uploads
    document.getElementById(`${columnId}-cert-upload`).addEventListener('change', (e) => handleGensCertUpload(columnId, e));
    document.getElementById(`${columnId}-key-upload`).addEventListener('change', (e) => handleGensKeyUpload(columnId, e));
    document.getElementById(`${columnId}-ca-upload`).addEventListener('change', (e) => handleGensCaUpload(columnId, e));
    
    // Validate button
    document.getElementById(`${columnId}-validate-btn`).addEventListener('click', () => validateGensCert(columnId));
    
    // Enroll button
    document.getElementById(`${columnId}-enroll-btn`).addEventListener('click', () => enrollGens(columnId));
}

/**
 * Entfernt eine Spalte aus DOM und State
 * @param {string} columnId - ID der zu entfernenden Spalte
 */
function removeColumn(columnId) {
    const columnIndex = appState.columns.findIndex(col => col.id === columnId);
    
    if (columnIndex === -1) {
        console.error(`Column ${columnId} not found in state.`);
        return;
    }

    appState.columns.splice(columnIndex, 1);

    const columnElement = document.getElementById(columnId);
    if (columnElement) {
        columnElement.remove();
    }

    console.log(`Column ${columnId} removed. Current state:`, appState);
}

/**
 * Erstellt das DOM-Element für eine Spalte
 * @param {Object} columnData - Column-Daten-Objekt
 * @returns {HTMLElement} Column DOM-Element
 */
function createColumnElement(columnData) {
    const column = document.createElement('div');
    column.className = 'column';
    column.id = columnData.id;
    column.setAttribute('data-type', columnData.type);

    const badgeClass = `badge-${columnData.type}`;
    const typeName = columnData.type.charAt(0).toUpperCase() + columnData.type.slice(1);

    const sections = getSectionsForType(columnData.type);

    let sectionsHtml = '';
    
    if (columnData.type === 'gens') {
        sectionsHtml = createGensSections(columnData.id);
    } else {
        sectionsHtml = sections.map(section => `
            <div class="accordion-section">
                <button class="accordion-header" aria-expanded="false">
                    <span class="accordion-icon">▶</span>
                    <span class="accordion-title">${section.title}</span>
                </button>
                <div class="accordion-content">
                    <p>${section.placeholder}</p>
                </div>
            </div>
        `).join('');
    }

    column.innerHTML = `
        <div class="column-header">
            <div class="column-title">
                <span class="type-badge ${badgeClass}">${typeName}</span>
                <span class="column-id">${columnData.id}</span>
            </div>
            <button class="remove-column-btn" onclick="removeColumn('${columnData.id}')" aria-label="Remove column">×</button>
        </div>
        
        <div class="column-content">
            ${sectionsHtml}
        </div>
    `;

    return column;
}

/**
 * Erstellt Gens-spezifische Sections
 * @param {string} columnId - Column ID
 * @returns {string} HTML String
 */
function createGensSections(columnId) {
    return `
        <!-- Section 1: Loading -->
        <div class="accordion-section">
            <button class="accordion-header" aria-expanded="false">
                <span class="accordion-icon">▶</span>
                <span class="accordion-title">Loading</span>
            </button>
            <div class="accordion-content">
                <div class="upload-group">
                    <label class="upload-label">Certificate (PEM)</label>
                    <input 
                        type="file" 
                        id="${columnId}-cert-upload" 
                        accept=".pem,.crt,.cer"
                        style="display: none;"
                    >
                    <button class="btn-upload" onclick="document.getElementById('${columnId}-cert-upload').click()">
                        📄 Upload Cert
                    </button>
                    <span id="${columnId}-cert-status" class="upload-status">–</span>
                </div>

                <div class="upload-group">
                    <label class="upload-label">Private Key (PEM)</label>
                    <input 
                        type="file" 
                        id="${columnId}-key-upload" 
                        accept=".pem,.key"
                        style="display: none;"
                    >
                    <button class="btn-upload" onclick="document.getElementById('${columnId}-key-upload').click()">
                        🔑 Upload Key
                    </button>
                    <span id="${columnId}-key-status" class="upload-status">–</span>
                </div>

                <div class="upload-group">
                    <label class="upload-label">CA Certificate (PEM)</label>
                    <input 
                        type="file" 
                        id="${columnId}-ca-upload" 
                        accept=".pem,.crt,.cer"
                        style="display: none;"
                    >
                    <button class="btn-upload" onclick="document.getElementById('${columnId}-ca-upload').click()">
                        📜 Upload CA Cert
                    </button>
                    <span id="${columnId}-ca-status" class="upload-status">–</span>
                </div>

                <div id="${columnId}-loaded-info" style="display: none; margin-top: var(--spacing-md);">
                    <div class="info-row">
                        <span class="info-label">CN:</span>
                        <span id="${columnId}-cn-display" class="info-value">–</span>
                    </div>
                    <button 
                        id="${columnId}-validate-btn" 
                        class="btn-validate" 
                        title="Validate Certificate"
                        style="margin-top: var(--spacing-sm);"
                        disabled
                    >
                        🔍 Validate
                    </button>
                </div>
            </div>
        </div>

        <!-- Section 2: Registration -->
        <div class="accordion-section">
            <button class="accordion-header" aria-expanded="false">
                <span class="accordion-icon">▶</span>
                <span class="accordion-title">Registration</span>
            </button>
            <div class="accordion-content">
                <label class="upload-label">Gens Name</label>
                <input 
                    type="text" 
                    id="${columnId}-name-input" 
                    class="input-field"
                    placeholder="e.g., perplexity"
                >
                <button class="btn-secondary" onclick="generateGensQrCode('${columnId}')" style="width: 100%;">
                    Generate QR Code
                </button>

                <div id="${columnId}-qr-display" class="qr-display" style="display: none;">
                    <div id="${columnId}-qr-container" class="qr-container"></div>
                    <p style="font-size: 12px; color: var(--color-text-light); margin-top: var(--spacing-sm);">
                        Scan QR or copy JSON below:
                    </p>
                    <div id="${columnId}-qr-text" class="qr-text"></div>
                </div>
            </div>
        </div>

        <!-- Section 3: Activation -->
        <div class="accordion-section">
            <button class="accordion-header" aria-expanded="false">
                <span class="accordion-icon">▶</span>
                <span class="accordion-title">Activation</span>
            </button>
            <div class="accordion-content">
                <button 
                    id="${columnId}-enroll-btn" 
                    class="btn-secondary" 
                    style="width: 100%;"
                    disabled
                >
                    Perform Enrollment
                </button>

                <div id="${columnId}-enroll-result" style="display: none; margin-top: var(--spacing-md);">
                    <div class="info-row">
                        <span class="info-label">CN:</span>
                        <span id="${columnId}-enrolled-cn" class="info-value">–</span>
                    </div>

                    <div class="download-group">
                        <button id="${columnId}-download-cert" class="btn-download" style="display: none;">
                            💾 Download cert.pem
                        </button>
                        <button id="${columnId}-download-key" class="btn-download" style="display: none;">
                            💾 Download key.pem
                        </button>
                        <button id="${columnId}-download-ca" class="btn-download" style="display: none;">
                            💾 Download ca-cert.pem
                        </button>
                    </div>
                </div>

                <div id="${columnId}-enroll-error" class="error-display" style="display: none;"></div>
            </div>
        </div>

        <!-- Section 4: Badges -->
        <div class="accordion-section">
            <button class="accordion-header" aria-expanded="true">
                <span class="accordion-icon">▶</span>
                <span class="accordion-title">Badges</span>
            </button>
            <div class="accordion-content expanded">
                <div class="badges-container">
                    <div id="${columnId}-registered-badge" class="status-badge badge-success" style="display: none;">
                        ✅ Gens Registered
                    </div>
                    <div id="${columnId}-enrolled-badge" class="status-badge badge-success" style="display: none;">
                        ✅ Gens Enrolled
                    </div>
                    <div id="${columnId}-validation-badge" class="status-badge" style="display: none;">
                        <!-- Dynamically filled -->
                    </div>
                </div>
            </div>
        </div>
    `;
}

/**
 * Gibt die Sections für einen bestimmten Column-Typ zurück
 * @param {string} type - Column-Typ
 * @returns {Array} Array von Section-Objekten
 */
function getSectionsForType(type) {
    const sections = {
        gens: [
            { title: 'Loading', placeholder: 'loading-section', isCustom: true },
            { title: 'Registration', placeholder: 'registration-section', isCustom: true },
            { title: 'Activation', placeholder: 'activation-section', isCustom: true },
            { title: 'Badges', placeholder: 'badges-section', isCustom: true }
        ],
        human: [
            { title: 'Loading', placeholder: 'Content coming in Feature 4' },
            { title: 'Registration', placeholder: 'Content coming in Feature 2' },
            { title: 'Activation', placeholder: 'Content coming in Feature 3' }
        ]
    };

    return sections[type] || [];
}

// === Accordion Functionality ===

/**
 * Initialisiert Accordion-Funktionalität für ein Element
 * @param {HTMLElement} container - Container-Element mit Accordions
 */
function initializeAccordions(container = document) {
    const accordionHeaders = container.querySelectorAll('.accordion-header');
    
    accordionHeaders.forEach(header => {
        header.replaceWith(header.cloneNode(true));
    });

    const newHeaders = container.querySelectorAll('.accordion-header');
    newHeaders.forEach(header => {
        header.addEventListener('click', toggleAccordion);
    });
}

/**
 * Toggle-Funktion für Accordion
 * @param {Event} event - Click-Event
 */
function toggleAccordion(event) {
    const header = event.currentTarget;
    const content = header.nextElementSibling;
    const isExpanded = header.getAttribute('aria-expanded') === 'true';

    if (isExpanded) {
        header.setAttribute('aria-expanded', 'false');
        content.classList.remove('expanded');
    } else {
        header.setAttribute('aria-expanded', 'true');
        content.classList.add('expanded');
    }
}

// === Initialization ===

document.addEventListener('DOMContentLoaded', () => {
    // Lade Gateway-URL
    const savedUrl = loadGatewayUrl();
    document.getElementById('gateway-url').value = savedUrl;

    // Gateway Event Listeners
    document.getElementById('save-gateway-btn').addEventListener('click', handleSaveGatewayUrl);
    
    document.getElementById('gateway-url').addEventListener('keypress', (event) => {
        if (event.key === 'Enter') {
            handleSaveGatewayUrl();
        }
    });

    // Initialisiere Ager-Spalte im State
    appState.columns.push({
        id: 'ager-1',
        type: 'ager',
        state: 'NOT_LOADED',
        data: {}
    });

    // Ager Certificate & Key Upload
    document.getElementById('ager-cert-upload').addEventListener('change', handleAgerCertUpload);
    document.getElementById('ager-key-upload').addEventListener('change', handleAgerKeyUpload);

    // Ager Certificate Validation
    document.getElementById('ager-validate-btn').addEventListener('click', validateAgerCert);

    // Ager Register Gens
    document.getElementById('ager-register-gens-btn').addEventListener('click', registerGensViaAger);

    // Initialisiere Accordions
    initializeAccordions();

    // Add Column Buttons
    document.getElementById('add-gens-btn').addEventListener('click', () => {
        addColumn('gens');
    });

    document.getElementById('add-human-btn').addEventListener('click', () => {
        addColumn('human');
    });

    console.log('✅ JEDO App initialized. Initial state:', appState);
    console.log('💡 Tip: Use window.debugState() in console for state debugging');
});
