// ============================================================================
// JEDO Gateway Console - Feature 2: Ager-Verwaltung & Zertifikats-Upload
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

// === Ager Certificate Management ===

/**
 * Parsed CN-String in Username und Affiliation
 * @param {string} cn - Common Name (z.B. "alps.ea.jedo.dev")
 * @returns {Object} {username, affiliation}
 */
function parseCnToUserAndAffiliation(cn) {
    if (!cn || typeof cn !== 'string') {
        return { username: null, affiliation: null };
    }

    const firstDotIndex = cn.indexOf('.');
    
    if (firstDotIndex === -1) {
        return { username: cn, affiliation: null };
    }

    const username = cn.substring(0, firstDotIndex);
    const affiliation = cn.substring(firstDotIndex + 1);

    return { username, affiliation };
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
    const validationResult = document.getElementById('ager-validation-result');
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

    console.log(`Column ${columnId} added. Current state:`, appState);
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

    column.innerHTML = `
        <div class="column-header">
            <div class="column-title">
                <span class="type-badge ${badgeClass}">${typeName}</span>
                <span class="column-id">${columnData.id}</span>
            </div>
            <button class="remove-column-btn" onclick="removeColumn('${columnData.id}')" aria-label="Spalte entfernen">×</button>
        </div>
        
        <div class="column-content">
            ${sections.map(section => `
                <div class="accordion-section">
                    <button class="accordion-header" aria-expanded="false">
                        <span class="accordion-icon">▶</span>
                        <span class="accordion-title">${section.title}</span>
                    </button>
                    <div class="accordion-content">
                        <p>${section.placeholder}</p>
                    </div>
                </div>
            `).join('')}
        </div>
    `;

    return column;
}

/**
 * Gibt die Sections für einen bestimmten Column-Typ zurück
 * @param {string} type - Column-Typ
 * @returns {Array} Array von Section-Objekten
 */
function getSectionsForType(type) {
    const sections = {
        gens: [
            { title: 'Loading', placeholder: 'Content coming in Feature 4' },
            { title: 'Registration', placeholder: 'Content coming in Feature 2' },
            { title: 'Activation', placeholder: 'Content coming in Feature 3' }
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
