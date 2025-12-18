// ============================================================================
// JEDO Gateway Console - Features 1-4 Complete
// ============================================================================

// === Gateway Configuration ===

const GATEWAY_CONFIG = {
    STORAGE_KEY: 'jedo_gateway_url',
    DEFAULT_URL: 'https://localhost:53901'
};

function loadGatewayUrl() {
    try {
        const storedUrl = localStorage.getItem(GATEWAY_CONFIG.STORAGE_KEY);
        return storedUrl || GATEWAY_CONFIG.DEFAULT_URL;
    } catch (error) {
        console.error('Error loading gateway URL from localStorage:', error);
        return GATEWAY_CONFIG.DEFAULT_URL;
    }
}

function saveGatewayUrl(url) {
    try {
        localStorage.setItem(GATEWAY_CONFIG.STORAGE_KEY, url);
        return true;
    } catch (error) {
        console.error('Error saving gateway URL to localStorage:', error);
        return false;
    }
}

function validateGatewayUrl(url) {
    url = url.trim();
    if (!url) return { success: false, message: 'URL darf nicht leer sein.' };
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

function showFeedback(message, isSuccess = true) {
    const feedbackElement = document.getElementById('save-feedback');
    const inputElement = document.getElementById('gateway-url');
    feedbackElement.textContent = message;
    feedbackElement.style.color = isSuccess ? 'var(--color-success)' : '#e74c3c';
    feedbackElement.classList.add('show');
    if (isSuccess) {
        inputElement.classList.add('success-flash');
        setTimeout(() => inputElement.classList.remove('success-flash'), 600);
    }
    setTimeout(() => feedbackElement.classList.remove('show'), 3000);
}

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

function getGatewayUrl() {
    return document.getElementById('gateway-url').value.trim();
}

// === State Management ===

const appState = {
    columns: [],
    counters: { ager: 1, gens: 0, human: 0 }
};

function getAllColumns() {
    return appState.columns;
}

function getColumnById(columnId) {
    return appState.columns.find(col => col.id === columnId) || null;
}

function getColumnsByType(type) {
    return appState.columns.filter(col => col.type === type);
}

function setColumnState(columnId, newState) {
    const validStates = ['NOT_LOADED', 'LOADED', 'REGISTERED', 'ENROLLED'];
    if (!validStates.includes(newState)) {
        console.error(`Invalid state: ${newState}`);
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

function getColumnState(columnId) {
    const column = getColumnById(columnId);
    return column ? column.state : null;
}

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

function getColumnData(columnId) {
    const column = getColumnById(columnId);
    return column ? column.data : null;
}

function triggerStateUpdate(columnId, newState) {
    const event = new CustomEvent('columnStateChanged', {
        detail: { columnId, newState }
    });
    document.dispatchEvent(event);
}

function exportState() {
    return JSON.parse(JSON.stringify(appState));
}

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

function debugState() {
    console.group('🔍 JEDO App State');
    console.log('Gateway URL:', getGatewayUrl());
    console.log('Columns:', appState.columns);
    console.log('Counters:', appState.counters);
    console.groupEnd();
}

window.debugState = debugState;

// === Ager Certificate Management ===

function parseCnToUserAndAffiliation(cn) {
    if (!cn || typeof cn !== 'string') {
        return { username: null, fullUsername:null, affiliation: null };
    }
    const parts = cn.split('.');
    if (parts.length < 5) {
        console.warn(`⚠️ CN format too short: ${cn}`);
        return { username: parts[0] || null, fullUsername:null, affiliation: null };
    }
    if (parts.length === 5) {
        const username = parts[0];
        const ager = parts[1];
        const regnum = parts[2];
        const orbis = parts[3];
        const env = parts[4];
        const affiliation = `${orbis}.${regnum}.${ager}`;  // e.g. jedo.ea.alps
        const fqdn = `${ager}.${regnum}.${orbis}.${env}`;  // e.g. alps ea.jedo.dev
        console.log('🔍 CN Parsing (5 parts):', {
            input: cn,
            username: username,
            fqdn: fqdn,
            affiliation: affiliation,
            breakdown: { username, ager, regnum, orbis, env }
        });
        return { username, fqdn, affiliation };
    }
    console.warn(`⚠️ Unexpected CN format: ${cn}`);
    const username = parts[0];
    return { username, fqdn, affiliation: null };
}

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

function handleAgerCertUpload(event) {
    const file = event.target.files[0];
    if (!file) return;
    const reader = new FileReader();
    reader.onload = function(e) {
        const pemContent = e.target.result;
        const cn = extractCnFromCert(pemContent);
        if (!cn) {
            showFeedback('❌ Could not extract CN from certificate', false);
            return;
        }
        const { username, fqdn, affiliation } = parseCnToUserAndAffiliation(cn);
        updateColumnData('ager-1', {
            certPem: pemContent,
            cn: cn,
            username: username,
            fqdn: fqdn,
            affiliation: affiliation
        });
        document.getElementById('ager-cert-status').textContent = `✓ ${file.name}`;
        document.getElementById('ager-cert-status').classList.add('success');
        document.getElementById('ager-cn-display').textContent = cn;
        document.getElementById('ager-username-display').textContent = username || '–';
        document.getElementById('ager-fqdn-display').textContent = fqdn || '–';
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

function handleAgerKeyUpload(event) {
    const file = event.target.files[0];
    if (!file) return;
    const reader = new FileReader();
    reader.onload = function(e) {
        const keyContent = e.target.result;
        if (!keyContent.includes('BEGIN') || !keyContent.includes('PRIVATE KEY')) {
            showFeedback('❌ Invalid private key format (PEM expected)', false);
            return;
        }
        updateColumnData('ager-1', { keyPem: keyContent });
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

function checkAgerLoadedState() {
    const agerData = getColumnData('ager-1');
    if (agerData.certPem && agerData.keyPem) {
        setColumnState('ager-1', 'LOADED');
        document.getElementById('ager-loaded-badge').style.display = 'block';
        console.log('✅ Ager fully loaded');
    }
}

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
        console.log('✅ Certificate validated successfully');
    } catch (error) {
        updateColumnData('ager-1', { isValid: false, validUntil: null });
        validationBadge.textContent = `❌ Validation failed: ${error.message}`;
        validationBadge.className = 'status-badge badge-error';
        validationBadge.style.display = 'block';
        console.error('Certificate validation failed:', error);
    }
}

// === Gens Management ===

function generateSecurePassword(length = 16) {
    const lowercase = 'abcdefghijklmnopqrstuvwxyz';
    const uppercase = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    const numbers = '0123456789';
    const special = '-_!=';
    const charset = lowercase + uppercase + numbers + special;
    let password = '';
    const array = new Uint32Array(length);
    window.crypto.getRandomValues(array);
    for (let i = 0; i < length; i++) {
        password += charset[array[i] % charset.length];
    }
    if (!/[a-z]/.test(password)) password = password.slice(0, -1) + lowercase[Math.floor(Math.random() * lowercase.length)];
    if (!/[A-Z]/.test(password)) password = password.slice(0, -1) + uppercase[Math.floor(Math.random() * uppercase.length)];
    if (!/[0-9]/.test(password)) password = password.slice(0, -1) + numbers[Math.floor(Math.random() * numbers.length)];
    if (!/[\-_.~!=]/.test(password)) password = password.slice(0, -1) + special[Math.floor(Math.random() * special.length)];
    return password;
}

function generateGensQrCode(columnId) {
    const nameInput = document.getElementById(`${columnId}-name-input`);
    const name = nameInput.value.trim();
    if (!name) {
        showFeedback('❌ Please enter a Gens name', false);
        return;
    }
    if (!/^[a-zA-Z0-9_-]+$/.test(name)) {
        showFeedback('❌ Name can only contain letters, numbers, dash and underscore', false);
        return;
    }
    const agerData = getColumnData('ager-1');
    if (!agerData || !agerData.affiliation) {
        showFeedback('❌ Please load Ager certificate first', false);
        return;
    }
    const username = `${name}`;
    const password = generateSecurePassword(16);
    const qrData = JSON.stringify({ username, password });
    updateColumnData(columnId, {
        name: name,
        username: username,
        password: password,
        qrCodeData: qrData,
        fqdn: agerData.fqdn,
        affiliation: agerData.affiliation
    });
    const qrContainer = document.getElementById(`${columnId}-qr-container`);
    qrContainer.innerHTML = '';
    new QRCode(qrContainer, {
        text: qrData,
        width: 200,
        height: 200,
        colorDark: '#000000',
        colorLight: '#ffffff',
        correctLevel: QRCode.CorrectLevel.M
    });
    document.getElementById(`${columnId}-qr-text`).textContent = qrData;
    document.getElementById(`${columnId}-qr-display`).style.display = 'block';
    console.log(`✅ QR Code generated for ${username}`);
}

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
    const fullUsername = `${qrData.username}.${agerData.fqdn}`;
    const payload = {
        certificate: agerData.certPem,
        privateKey: agerData.keyPem,
        username: fullUsername,
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
    console.log('📤 Registering Gens:', fullUsername);
    try {
        const response = await fetch(endpoint, {
            method: 'POST',
            mode: 'cors',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload)
        });
        const result = await response.json();
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

async function enrollGens(columnId) {
    const gensData = getColumnData(columnId);
    const errorDiv = document.getElementById(`${columnId}-enroll-error`);
    const resultDiv = document.getElementById(`${columnId}-enroll-result`);
    const enrollBtn = document.getElementById(`${columnId}-enroll-btn`);
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
    const fullUsername = `${gensData.username}.${gensData.fqdn}`;
    const payload = {
        username: fullUsername,
        secret: gensData.password,
        enrollmentType: "x509",
        role: "gens",
        attrReqs: [
            { name: 'hf.Affiliation', optional: false },
            { name: 'hf.EnrollmentID', optional: false },
            { name: 'hf.Type', optional: false },
            { name: 'role', optional: false },
            { name: 'hf.Registrar.Roles', optional: false },
            { name: 'hf.Registrar.Attributes', optional: false },
            { name: 'hf.Revoker', optional: false }
        ]
    };
    console.log('📤 Enrolling Gens:', fullUsername);
    enrollBtn.disabled = true;
    enrollBtn.textContent = 'Enrolling...';
    try {
        const gatewayUrl = getGatewayUrl();
        const response = await fetch(`${gatewayUrl}/api/v1/ca/certificates/enroll`, {
            method: 'POST',
            mode: 'cors',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload)
        });
        const result = await response.json();
        if (response.ok && result.data) {
            const { certificate, privateKey, rootCertificate } = result.data;
            const cn = extractCnFromCert(certificate);
            const { username: parsedUsername, fqdn: parsedFqdn, affiliation: parsedAffiliation } = parseCnToUserAndAffiliation(cn);
            updateColumnData(columnId, {
                certPem: certificate,
                keyPem: privateKey,
                caCertPem: rootCertificate,
                cn: cn,
                fqdn: parsedFqdn || gensData.fqdn,
                affiliation: parsedAffiliation || gensData.affiliation
            });
            setColumnState(columnId, 'ENROLLED');
            document.getElementById(`${columnId}-enrolled-cn`).textContent = cn || 'N/A';
            document.getElementById(`${columnId}-enrolled-username`).textContent = gensData.username || 'N/A';
            document.getElementById(`${columnId}-enrolled-fqdn`).textContent = parsedFqdn || gensData.fqdn || 'N/A';
            document.getElementById(`${columnId}-enrolled-affiliation`).textContent = parsedAffiliation || gensData.affiliation || 'N/A';
            resultDiv.style.display = 'block';
            document.getElementById(`${columnId}-enrolled-badge`).style.display = 'block';
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

function setupGensDownloads(columnId) {
    const gensData = getColumnData(columnId);
    if (!gensData || !gensData.certPem) return;
    const username = gensData.username || 'gens';
    const certBtn = document.getElementById(`${columnId}-download-cert`);
    certBtn.style.display = 'block';
    certBtn.onclick = () => {
        downloadFile(gensData.certPem, `${username}-cert.pem`);
        console.log(`📥 Downloaded ${username}-cert.pem`);
    };
    const keyBtn = document.getElementById(`${columnId}-download-key`);
    keyBtn.style.display = 'block';
    keyBtn.onclick = () => {
        downloadFile(gensData.keyPem, `${username}-key.pem`);
        console.log(`📥 Downloaded ${username}-key.pem`);
    };
    const caBtn = document.getElementById(`${columnId}-download-ca`);
    caBtn.style.display = 'block';
    caBtn.onclick = () => {
        downloadFile(gensData.caCertPem, `${username}-ca-cert.pem`);
        console.log(`📥 Downloaded ${username}-ca-cert.pem`);
    };
}

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

function checkGensLoadedState(columnId) {
    const gensData = getColumnData(columnId);
    
    if (gensData.certPem && gensData.keyPem && gensData.caCertPem) {
        // Extract CN from certificate
        const cn = extractCnFromCert(gensData.certPem);
        
        // ← NEU: Parse CN to get username and affiliation
        const { username, fqdn, affiliation } = parseCnToUserAndAffiliation(cn);
        
        // Update data with CN, username AND affiliation
        updateColumnData(columnId, { 
            cn: cn,
            username: username,
            fqdn: fqdn,
            affiliation: affiliation
        });
        
        // Update UI
        document.getElementById(`${columnId}-cn-display`).textContent = cn || 'N/A';
        document.getElementById(`${columnId}-username-display`).textContent = username || '–';
        document.getElementById(`${columnId}-fqdn-display`).textContent = fqdn || '–';
        document.getElementById(`${columnId}-affiliation-display`).textContent = affiliation || '–';
        document.getElementById(`${columnId}-loaded-info`).style.display = 'block';
        document.getElementById(`${columnId}-validate-btn`).disabled = false;
        
        // Set state to ENROLLED
        setColumnState(columnId, 'ENROLLED');
        document.getElementById(`${columnId}-enrolled-badge`).style.display = 'block';
        
        console.log(`✅ Gens ${columnId} fully loaded from files`, {
            cn: cn,
            username: username,
            fqdn: fqdn,
            affiliation: affiliation
        });
    }
}

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

// === Human Management (Feature 4) ===

/**
 * Fallback UUID Generator für ältere Browser
 */
function generateFallbackUUID() {
    return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, c => {
        const r = Math.random() * 16 | 0;
        return (c === 'x' ? r : (r & 0x3 | 0x8)).toString(16);
    });
}

/**
 * Generiert QR-Code für Human-Registrierung (UUID-basiert)
 * @param {string} columnId - ID der Human-Spalte
 */
function generateHumanQrCode(columnId) {
    // Check if any Gens is enrolled
    const enrolledGens = appState.columns.filter(col => 
        col.type === 'gens' && col.state === 'ENROLLED'
    );
    
    if (enrolledGens.length === 0) {
        showFeedback('❌ Please enroll at least one Gens first', false);
        return;
    }
    
    // Get selected Gens from dropdown
    const gensSelect = document.getElementById(`${columnId}-gens-select`);
    const selectedGensId = gensSelect.value;
    
    if (!selectedGensId) {
        showFeedback('❌ Please select a Gens', false);
        return;
    }
    
    const gensData = getColumnData(selectedGensId);
    if (!gensData || !gensData.affiliation) {
        showFeedback('❌ Selected Gens has no affiliation', false);
        return;
    }
    
    // Generate UUID and password
    const uuid = crypto.randomUUID ? crypto.randomUUID() : generateFallbackUUID();
    const username = `${uuid}`;
    const password = generateSecurePassword(16);
    
    // Create QR data
    const qrData = JSON.stringify({ username, password });
    
    // Update Human state
    updateColumnData(columnId, {
        username: username,
        password: password,
        qrCodeData: qrData,
        registeredByGensId: selectedGensId,
        fqdn: gensData.fqdn,
        affiliation: gensData.affiliation
    });
    
    // Display QR Code
    const qrContainer = document.getElementById(`${columnId}-qr-container`);
    qrContainer.innerHTML = '';
    
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
    
    console.log(`✅ QR Code generated for Human ${username}`);
}

/**
 * Aktualisiert Gens-Auswahl-Dropdown für alle Human-Spalten
 */
function updateGensSelectDropdowns() {
    const enrolledGens = appState.columns.filter(col => 
        col.type === 'gens' && col.state === 'ENROLLED'
    );
    
    // Update all human column dropdowns
    appState.columns.filter(col => col.type === 'human').forEach(humanCol => {
        const select = document.getElementById(`${humanCol.id}-gens-select`);
        if (!select) return;
        
        const currentValue = select.value;
        select.innerHTML = '<option value="">-- Select a Gens --</option>';
        
        enrolledGens.forEach(gens => {
            const option = document.createElement('option');
            option.value = gens.id;
            option.textContent = `${gens.id} (${gens.data.username || 'unnamed'})`;
            select.appendChild(option);
        });
        
        // Restore previous selection if still valid
        if (currentValue && enrolledGens.find(g => g.id === currentValue)) {
            select.value = currentValue;
        }
    });
}

/**
 * Registriert einen Human via Gateway (als Gens)
 * @param {string} gensId - ID der Gens-Spalte
 */
async function registerHumanViaGens(gensId) {
    const qrInput = document.getElementById(`${gensId}-human-qr-input`);
    const successDiv = document.getElementById(`${gensId}-human-register-success`);
    const errorDiv = document.getElementById(`${gensId}-human-register-error`);
    
    successDiv.style.display = 'none';
    errorDiv.style.display = 'none';
    
    // Parse QR data
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
    
    // Check Gens is enrolled
    const gensData = getColumnData(gensId);
    if (!gensData || !gensData.certPem || !gensData.keyPem) {
        showFeedback('❌ Gens must be enrolled first', false);
        return;
    }
    
    const fullUsername = `${qrData.username}.${gensData.fqdn}`;

    const payload = {
        certificate: gensData.certPem,
        privateKey: gensData.keyPem,
        username: fullUsername,
        secret: qrData.password,
        role: "human",
        affiliation: gensData.affiliation,
        attrs: [
            { role: "human" },
            { "hf.EnrollmentID": fullUsername }
        ]
    };
    
    const gatewayUrl = getGatewayUrl();
    const endpoint = `${gatewayUrl}/api/v1/ca/certificates/register`;
    
    console.log('📤 Registering Human:', fullUsername);
    
    try {
        const response = await fetch(endpoint, {
            method: 'POST',
            mode: 'cors',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload)
        });
        
        const result = await response.json();
        
        if (response.ok) {
            successDiv.style.display = 'block';
            
            // Find Human column by username and update state
            const humanColumn = appState.columns.find(col => 
                col.type === 'human' && col.data.username === qrData.username
            );
            
            if (humanColumn) {
                setColumnState(humanColumn.id, 'REGISTERED');
                
                // Show badge
                const badge = document.getElementById(`${humanColumn.id}-registered-badge`);
                if (badge) badge.style.display = 'block';
                
                // Enable enrollment button
                const enrollBtn = document.getElementById(`${humanColumn.id}-enroll-btn`);
                if (enrollBtn) enrollBtn.disabled = false;
            }
            
            console.log('✅ Human registered successfully');
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
 * Führt Idemix-Enrollment für Human durch
 * @param {string} columnId - Human Column ID
 */
async function enrollHuman(columnId) {
    const humanData = getColumnData(columnId);
    const errorDiv = document.getElementById(`${columnId}-enroll-error`);
    const resultDiv = document.getElementById(`${columnId}-enroll-result`);
    const enrollBtn = document.getElementById(`${columnId}-enroll-btn`);
    
    errorDiv.style.display = 'none';
    
    if (!humanData || !humanData.username || !humanData.password) {
        errorDiv.textContent = '❌ Missing username or password. Generate QR code first.';
        errorDiv.style.display = 'block';
        return;
    }
    
    if (getColumnState(columnId) !== 'REGISTERED') {
        errorDiv.textContent = '❌ Human must be registered first (via Gens)';
        errorDiv.style.display = 'block';
        return;
    }
    
    // Get the Gens that registered this Human
    const gensId = humanData.registeredByGensId;
    if (!gensId) {
        errorDiv.textContent = '❌ Cannot determine which Gens registered this Human';
        errorDiv.style.display = 'block';
        return;
    }
    
    const gensData = getColumnData(gensId);
    if (!gensData || !gensData.username) {
        errorDiv.textContent = '❌ Gens data not found';
        errorDiv.style.display = 'block';
        return;
    }
    
    // Build Idemix payload
    const payload = {
        username: humanData.username,
        secret: humanData.password,
        enrollmentType: "idemix",
        idemixCurve: "gurvy.Bn254",
        role: "human",
        gensName: gensData.username
    };
    
    console.log('📤 Enrolling Human (Idemix):', humanData.username);
    enrollBtn.disabled = true;
    enrollBtn.textContent = 'Enrolling...';
    
    try {
        const gatewayUrl = getGatewayUrl();
        const response = await fetch(`${gatewayUrl}/api/v1/ca/certificates/enroll`, {
            method: 'POST',
            mode: 'cors',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload)
        });
        
        const result = await response.json();
        
        if (response.ok && result.data) {
            const { signerConfig, issuerPublicKey, issuerRevocationPublicKey, curve } = result.data;
            
            // Validate SignerConfig
            if (!signerConfig || signerConfig.length < 100) {
                errorDiv.textContent = '❌ SignerConfig invalid or too small';
                errorDiv.style.display = 'block';
                enrollBtn.disabled = false;
                enrollBtn.textContent = 'Perform Enrollment';
                return;
            }
            
            // Update state
            updateColumnData(columnId, {
                signerConfig: signerConfig,
                issuerPublicKey: issuerPublicKey || null,
                issuerRevocationPublicKey: issuerRevocationPublicKey || null,
                curve: curve || 'gurvy.Bn254'
            });
            
            setColumnState(columnId, 'ENROLLED');
            
            // Update UI - show username as identification
            document.getElementById(`${columnId}-enrolled-username`).textContent = humanData.username || 'N/A';
            document.getElementById(`${columnId}-enrolled-affiliation`).textContent = humanData.affiliation || 'N/A';
            resultDiv.style.display = 'block';
            
            // Show badges
            document.getElementById(`${columnId}-enrolled-badge`).style.display = 'block';
            
            // Validate SignerConfig size
            validateHumanSignerConfig(columnId);
            
            // Setup download buttons
            setupHumanDownloads(columnId);
            
            enrollBtn.textContent = '✅ Enrolled';
            
            console.log('✅ Human enrolled successfully (Idemix)');
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
 * Setup Download-Buttons für Human-Credentials
 * @param {string} columnId - Human Column ID
 */
function setupHumanDownloads(columnId) {
    const humanData = getColumnData(columnId);
    if (!humanData || !humanData.signerConfig) return;
    
    const username = humanData.username || 'human';
    
    // SignerConfig Download
    const signerBtn = document.getElementById(`${columnId}-download-signer`);
    signerBtn.style.display = 'block';
    signerBtn.onclick = () => {
        downloadFile(humanData.signerConfig, `${username}-SignerConfig`);
        console.log(`📥 Downloaded ${username}-SignerConfig`);
    };
    
    // IssuerPublicKey Download (optional)
    if (humanData.issuerPublicKey) {
        const ipkBtn = document.getElementById(`${columnId}-download-ipk`);
        ipkBtn.style.display = 'block';
        ipkBtn.onclick = () => {
            downloadFile(humanData.issuerPublicKey, `${username}-IssuerPublicKey`);
            console.log(`📥 Downloaded ${username}-IssuerPublicKey`);
        };
    }
    
    // IssuerRevocationPublicKey Download (optional)
    if (humanData.issuerRevocationPublicKey) {
        const irvkBtn = document.getElementById(`${columnId}-download-irvk`);
        irvkBtn.style.display = 'block';
        irvkBtn.onclick = () => {
            downloadFile(humanData.issuerRevocationPublicKey, `${username}-IssuerRevocationPublicKey`);
            console.log(`📥 Downloaded ${username}-IssuerRevocationPublicKey`);
        };
    }
}

/**
 * Validiert SignerConfig (Größencheck)
 * @param {string} columnId - Human Column ID
 */
function validateHumanSignerConfig(columnId) {
    const humanData = getColumnData(columnId);
    const validationBadge = document.getElementById(`${columnId}-validation-badge`);
    
    if (!humanData || !humanData.signerConfig) {
        validationBadge.textContent = '❌ No SignerConfig loaded';
        validationBadge.className = 'status-badge badge-error';
        validationBadge.style.display = 'block';
        updateColumnData(columnId, { isValid: false });
        return;
    }
    
    const size = humanData.signerConfig.length;
    
    if (size < 100) {
        validationBadge.textContent = `❌ SignerConfig too small (${size} bytes)`;
        validationBadge.className = 'status-badge badge-error';
        validationBadge.style.display = 'block';
        updateColumnData(columnId, { isValid: false });
        return;
    }
    
    validationBadge.textContent = `✅ SignerConfig valid (${size} bytes)`;
    validationBadge.className = 'status-badge badge-success';
    validationBadge.style.display = 'block';
    updateColumnData(columnId, { isValid: true });
    
    console.log(`✅ Human SignerConfig validated for ${columnId}`);
}

/**
 * Handler für Human SignerConfig Upload
 * @param {string} columnId - Human Column ID
 * @param {Event} event - File Input Event
 */
function handleHumanSignerUpload(columnId, event) {
    const file = event.target.files[0];
    if (!file) return;
    
    const reader = new FileReader();
    reader.onload = function(e) {
        const content = e.target.result;
        
        updateColumnData(columnId, { signerConfig: content });
        
        document.getElementById(`${columnId}-signer-status`).textContent = `✓ ${file.name}`;
        document.getElementById(`${columnId}-signer-status`).classList.add('success');
        
        checkHumanLoadedState(columnId);
        
        console.log(`✅ Human SignerConfig uploaded for ${columnId}`);
    };
    reader.readAsText(file);
}

/**
 * Handler für Human IssuerPublicKey Upload
 * @param {string} columnId - Human Column ID
 * @param {Event} event - File Input Event
 */
function handleHumanIpkUpload(columnId, event) {
    const file = event.target.files[0];
    if (!file) return;
    
    const reader = new FileReader();
    reader.onload = function(e) {
        const content = e.target.result;
        
        updateColumnData(columnId, { issuerPublicKey: content });
        
        document.getElementById(`${columnId}-ipk-status`).textContent = `✓ ${file.name}`;
        document.getElementById(`${columnId}-ipk-status`).classList.add('success');
        
        console.log(`✅ Human IssuerPublicKey uploaded for ${columnId}`);
    };
    reader.readAsText(file);
}

/**
 * Handler für Human IssuerRevocationPublicKey Upload
 * @param {string} columnId - Human Column ID
 * @param {Event} event - File Input Event
 */
function handleHumanIrvkUpload(columnId, event) {
    const file = event.target.files[0];
    if (!file) return;
    
    const reader = new FileReader();
    reader.onload = function(e) {
        const content = e.target.result;
        
        updateColumnData(columnId, { issuerRevocationPublicKey: content });
        
        document.getElementById(`${columnId}-irvk-status`).textContent = `✓ ${file.name}`;
        document.getElementById(`${columnId}-irvk-status`).classList.add('success');
        
        console.log(`✅ Human IssuerRevocationPublicKey uploaded for ${columnId}`);
    };
    reader.readAsText(file);
}

/**
 * Prüft ob mindestens SignerConfig geladen ist
 * @param {string} columnId - Human Column ID
 */
function checkHumanLoadedState(columnId) {
    const humanData = getColumnData(columnId);
    
    if (humanData.signerConfig) {
// TODO:
        // // Try to extract username from signerConfig (if possible)
        // // For now, we can't parse SignerConfig easily, so we just mark as loaded
        
        // // Set state to ENROLLED
        // setColumnState(columnId, 'ENROLLED');
        
        // // Show loaded info
        // document.getElementById(`${columnId}-loaded-info`).style.display = 'block';
        // document.getElementById(`${columnId}-validate-btn`).disabled = false;
        
        // // Show badge
        // document.getElementById(`${columnId}-enrolled-badge`).style.display = 'block';
        
        // console.log(`✅ Human ${columnId} loaded from files`);

        const username = humanData.username || 'N/A';
        const fqdn = humanData.fqdn || 'N/A';
        const affiliation = humanData.affiliation || 'N/A';
        
        document.getElementById(`${columnId}-username-display`).textContent = username;
        document.getElementById(`${columnId}-fqdn-display`).textContent = fqdn;
        document.getElementById(`${columnId}-affiliation-display`).textContent = affiliation;
        document.getElementById(`${columnId}-loaded-info`).style.display = 'block';
        document.getElementById(`${columnId}-validate-btn`).disabled = false;
        
        setColumnState(columnId, 'ENROLLED');
        document.getElementById(`${columnId}-enrolled-badge`).style.display = 'block';
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
    
    // Attach event listeners
    if (type === 'gens') {
        attachGensEventListeners(columnId);
    } else if (type === 'human') {
        attachHumanEventListeners(columnId);
        updateGensSelectDropdowns();
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
 * Fügt Event-Listener für Human-Spalte hinzu
 * @param {string} columnId - Human Column ID
 */
function attachHumanEventListeners(columnId) {
    // Loading uploads
    document.getElementById(`${columnId}-signer-upload`).addEventListener('change', (e) => handleHumanSignerUpload(columnId, e));
    document.getElementById(`${columnId}-ipk-upload`).addEventListener('change', (e) => handleHumanIpkUpload(columnId, e));
    document.getElementById(`${columnId}-irvk-upload`).addEventListener('change', (e) => handleHumanIrvkUpload(columnId, e));
    
    // Validate button
    document.getElementById(`${columnId}-validate-btn`).addEventListener('click', () => validateHumanSignerConfig(columnId));
    
    // Enroll button
    document.getElementById(`${columnId}-enroll-btn`).addEventListener('click', () => enrollHuman(columnId));
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

    // Update Gens dropdowns if a Gens was removed
    updateGensSelectDropdowns();

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

    let sectionsHtml = '';
    
    if (columnData.type === 'gens') {
        sectionsHtml = createGensSections(columnData.id);
    } else if (columnData.type === 'human') {
        sectionsHtml = createHumanSections(columnData.id);
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
        <!-- Section 1: Preparation -->
        <div class="accordion-section">
            <button class="accordion-header" aria-expanded="false">
                <span class="accordion-icon">▶</span>
                <span class="accordion-title">Preparation</span>
            </button>
            <div class="accordion-content">
                <div class="upload-group">
                    <label class="upload-label">Certificate (PEM)</label>
                    <input type="file" id="${columnId}-cert-upload" accept=".pem,.crt,.cer" style="display: none;">
                    <button class="btn-upload" onclick="document.getElementById('${columnId}-cert-upload').click()">📄 Upload Cert</button>
                    <span id="${columnId}-cert-status" class="upload-status">–</span>
                </div>
                <div class="upload-group">
                    <label class="upload-label">Private Key (PEM)</label>
                    <input type="file" id="${columnId}-key-upload" accept=".pem,.key" style="display: none;">
                    <button class="btn-upload" onclick="document.getElementById('${columnId}-key-upload').click()">🔑 Upload Key</button>
                    <span id="${columnId}-key-status" class="upload-status">–</span>
                </div>
                <div class="upload-group">
                    <label class="upload-label">CA Certificate (PEM)</label>
                    <input type="file" id="${columnId}-ca-upload" accept=".pem,.crt,.cer" style="display: none;">
                    <button class="btn-upload" onclick="document.getElementById('${columnId}-ca-upload').click()">📜 Upload CA Cert</button>
                    <span id="${columnId}-ca-status" class="upload-status">–</span>
                </div>
                <div id="${columnId}-loaded-info" style="display: none; margin-top: var(--spacing-md);">
                    <div class="info-row">
                        <span class="info-label">CN:</span>
                        <span id="${columnId}-cn-display" class="info-value">–</span>
                    </div>
                    <div class="info-row">
                        <span class="info-label">Username:</span>
                        <span id="${columnId}-username-display" class="info-value">–</span>
                    </div>
                    <div class="info-row">
                        <span class="info-label">User-FQDN:</span>
                        <span id="${columnId}-fqdn-display" class="info-value">–</span>
                    </div>
                    <div class="info-row">
                        <span class="info-label">Affiliation:</span>
                        <span id="${columnId}-affiliation-display" class="info-value">–</span>
                    </div>
                    <button id="${columnId}-validate-btn" class="btn-validate" title="Validate Certificate" style="margin-top: var(--spacing-sm);" disabled>🔍 Validate</button>
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
                <input type="text" id="${columnId}-name-input" class="input-field" placeholder="e.g., perplexity">
                <button class="btn-secondary" onclick="generateGensQrCode('${columnId}')" style="width: 100%;">Generate QR Code</button>
                <div id="${columnId}-qr-display" class="qr-display" style="display: none;">
                    <div id="${columnId}-qr-container" class="qr-container"></div>
                    <p style="font-size: 12px; color: var(--color-text-light); margin-top: var(--spacing-sm);">Scan QR or copy JSON below:</p>
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
                <button id="${columnId}-enroll-btn" class="btn-secondary" style="width: 100%;" disabled>Perform Enrollment</button>
                <div id="${columnId}-enroll-result" style="display: none; margin-top: var(--spacing-md);">
                    <div class="info-row">
                        <span class="info-label">CN:</span>
                        <span id="${columnId}-enrolled-cn" class="info-value">–</span>
                    </div>
                    <div class="info-row">
                        <span class="info-label">Username:</span>
                        <span id="${columnId}-enrolled-username" class="info-value">–</span>
                    </div>
                    <div class="info-row">
                        <span class="info-label">User-FQDN:</span>
                        <span id="${columnId}-enrolled-fqdn" class="info-value">–</span>
                    </div>
                    <div class="info-row">
                        <span class="info-label">Affiliation:</span>
                        <span id="${columnId}-enrolled-affiliation" class="info-value">–</span>
                    </div>
                    <div class="download-group">
                        <button id="${columnId}-download-cert" class="btn-download" style="display: none;">💾 Download cert.pem</button>
                        <button id="${columnId}-download-key" class="btn-download" style="display: none;">💾 Download key.pem</button>
                        <button id="${columnId}-download-ca" class="btn-download" style="display: none;">💾 Download ca-cert.pem</button>
                    </div>
                </div>
                <div id="${columnId}-enroll-error" class="error-display" style="display: none;"></div>
            </div>
        </div>

        <!-- Section 4: Human Registration -->
        <div class="accordion-section">
            <button class="accordion-header" aria-expanded="false">
                <span class="accordion-icon">▶</span>
                <span class="accordion-title">Human Registration</span>
            </button>
            <div class="accordion-content">
                <label class="upload-label">Paste QR Code Data (JSON)</label>
                <textarea id="${columnId}-human-qr-input" class="input-field" rows="3" placeholder='{"username": "uuid.perplexity.ea.jedo.dev", "password": "..."}'></textarea>
                <button id="${columnId}-register-human-btn" class="btn-secondary" style="width: 100%;" onclick="registerHumanViaGens('${columnId}')">Register Human</button>
                <div id="${columnId}-human-register-success" style="display: none; margin-top: var(--spacing-md);">
                    <p style="color: var(--color-success); font-weight: 600;">✅ Human registered successfully!</p>
                </div>
                <div id="${columnId}-human-register-error" class="error-display" style="display: none;"></div>
            </div>
        </div>

        <!-- Section 5: Badges -->
        <div class="accordion-section">
            <button class="accordion-header" aria-expanded="true">
                <span class="accordion-icon">▶</span>
                <span class="accordion-title">Badges</span>
            </button>
            <div class="accordion-content expanded">
                <div class="badges-container">
                    <div id="${columnId}-registered-badge" class="status-badge badge-success" style="display: none;">✅ Gens Registered</div>
                    <div id="${columnId}-enrolled-badge" class="status-badge badge-success" style="display: none;">✅ Gens Enrolled</div>
                    <div id="${columnId}-validation-badge" class="status-badge" style="display: none;"></div>
                </div>
            </div>
        </div>
    `;
}

/**
 * Erstellt Human-spezifische Sections
 * @param {string} columnId - Column ID
 * @returns {string} HTML String
 */
function createHumanSections(columnId) {
    return `
        <!-- Section 1: Preparation -->
        <div class="accordion-section">
            <button class="accordion-header" aria-expanded="false">
                <span class="accordion-icon">▶</span>
                <span class="accordion-title">Preparation</span>
            </button>
            <div class="accordion-content">
                <div class="upload-group">
                    <label class="upload-label">SignerConfig</label>
                    <input type="file" id="${columnId}-signer-upload" style="display: none;">
                    <button class="btn-upload" onclick="document.getElementById('${columnId}-signer-upload').click()">📄 Upload SignerConfig</button>
                    <span id="${columnId}-signer-status" class="upload-status">–</span>
                </div>
                <div class="upload-group">
                    <label class="upload-label">IssuerPublicKey (optional)</label>
                    <input type="file" id="${columnId}-ipk-upload" style="display: none;">
                    <button class="btn-upload" onclick="document.getElementById('${columnId}-ipk-upload').click()">🔑 Upload IPK</button>
                    <span id="${columnId}-ipk-status" class="upload-status">–</span>
                </div>
                <div class="upload-group">
                    <label class="upload-label">IssuerRevocationPublicKey (optional)</label>
                    <input type="file" id="${columnId}-irvk-upload" style="display: none;">
                    <button class="btn-upload" onclick="document.getElementById('${columnId}-irvk-upload').click()">📜 Upload IRVK</button>
                    <span id="${columnId}-irvk-status" class="upload-status">–</span>
                </div>
                <div id="${columnId}-loaded-info" style="display: none; margin-top: var(--spacing-md);">
                    <div class="info-row">
                        <span class="info-label">Username:</span>
                        <span id="${columnId}-username-display" class="info-value">–</span>
                    </div>
                    <div class="info-row">
                        <span class="info-label">User-FQDN:</span>
                        <span id="${columnId}-fqdn-display" class="info-value">–</span>
                    </div>
                    <div class="info-row">
                        <span class="info-label">Affiliation:</span>
                        <span id="${columnId}-affiliation-display" class="info-value">–</span>
                    </div>
                    <button id="${columnId}-validate-btn" class="btn-validate" title="Validate SignerConfig" style="margin-top: var(--spacing-sm);" disabled>🔍 Validate</button>
                </div>
            </div>
        </div>

        <!-- Section 2: Registration Preparation -->
        <div class="accordion-section">
            <button class="accordion-header" aria-expanded="false">
                <span class="accordion-icon">▶</span>
                <span class="accordion-title">Registration Preparation</span>
            </button>
            <div class="accordion-content">
                <label class="upload-label">Select Gens to register with</label>
                <select id="${columnId}-gens-select" class="input-field">
                    <option value="">-- Select a Gens --</option>
                </select>
                <button class="btn-secondary" onclick="generateHumanQrCode('${columnId}')" style="width: 100%; margin-top: var(--spacing-sm);">Generate QR Code</button>
                <div id="${columnId}-qr-display" class="qr-display" style="display: none;">
                    <div id="${columnId}-qr-container" class="qr-container"></div>
                    <p style="font-size: 12px; color: var(--color-text-light); margin-top: var(--spacing-sm);">Scan QR or copy JSON below:</p>
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
                <button id="${columnId}-enroll-btn" class="btn-secondary" style="width: 100%;" disabled>Perform Enrollment</button>
                <div id="${columnId}-enroll-result" style="display: none; margin-top: var(--spacing-md);">
                    <div class="info-row">
                        <span class="info-label">Username:</span>
                        <span id="${columnId}-enrolled-username" class="info-value">–</span>
                    </div>
                    <div class="info-row">
                        <span class="info-label">User-FQDN:</span>
                        <span id="${columnId}-enrolled-fqdn" class="info-value">–</span>
                    </div>
                    <div class="download-group">
                        <button id="${columnId}-download-signer" class="btn-download" style="display: none;">💾 Download SignerConfig</button>
                        <button id="${columnId}-download-ipk" class="btn-download" style="display: none;">💾 Download IssuerPublicKey</button>
                        <button id="${columnId}-download-irvk" class="btn-download" style="display: none;">💾 Download IssuerRevocationPublicKey</button>
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
                    <div id="${columnId}-registered-badge" class="status-badge badge-success" style="display: none;">✅ Human Registered</div>
                    <div id="${columnId}-enrolled-badge" class="status-badge badge-success" style="display: none;">✅ Human Enrolled</div>
                    <div id="${columnId}-validation-badge" class="status-badge" style="display: none;"></div>
                </div>
            </div>
        </div>
    `;
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
    // Load Gateway URL
    const savedUrl = loadGatewayUrl();
    document.getElementById('gateway-url').value = savedUrl;

    // Gateway Event Listeners
    document.getElementById('save-gateway-btn').addEventListener('click', handleSaveGatewayUrl);
    document.getElementById('gateway-url').addEventListener('keypress', (event) => {
        if (event.key === 'Enter') {
            handleSaveGatewayUrl();
        }
    });

    // Check Readyness Button
    document.getElementById('check-ready-btn').addEventListener('click', () => {
        const gatewayUrl = getGatewayUrl();
        const readyUrl = `${gatewayUrl}/ready`;
        
        // Open in new window
        window.open(readyUrl, '_blank');
        
        console.log('🏥 Opening Gateway Readyness Check:', readyUrl);
    });

    // Initialize Ager in state
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

    // Initialize Accordions
    initializeAccordions();

    // Add Column Buttons
    document.getElementById('add-gens-btn').addEventListener('click', () => {
        addColumn('gens');
    });

    document.getElementById('add-human-btn').addEventListener('click', () => {
        addColumn('human');
    });

    // Listen to state changes to update Gens dropdowns
    document.addEventListener('columnStateChanged', (e) => {
        if (e.detail.newState === 'ENROLLED') {
            updateGensSelectDropdowns();
        }
    });

    console.log('✅ JEDO App initialized. Initial state:', appState);
    console.log('💡 Tip: Use window.debugState() in console for state debugging');
});
