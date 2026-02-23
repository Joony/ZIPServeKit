// Display technical details
document.addEventListener('DOMContentLoaded', function() {
    // Update timestamp
    document.getElementById('timestamp').textContent = new Date().toLocaleString();
    
    // Display URL information
    document.getElementById('protocol').textContent = window.location.protocol;
    document.getElementById('host').textContent = window.location.host || '(none)';
    document.getElementById('path').textContent = window.location.pathname;
    document.getElementById('url').textContent = window.location.href;
    document.getElementById('userAgent').textContent = navigator.userAgent;
    
    // JavaScript test button
    document.getElementById('jsTest').addEventListener('click', function() {
        const result = document.getElementById('jsResult');
        result.textContent = '✅ JavaScript is working! Random number: ' + Math.floor(Math.random() * 1000);
        result.style.background = '#D1F2EB';
        result.style.color = '#0B5345';
        
        // Animate
        result.style.animation = 'none';
        setTimeout(() => {
            result.style.animation = 'fadeIn 0.3s ease-in';
        }, 10);
    });
    
    // Fetch API test
    document.getElementById('fetchTest').addEventListener('click', async function() {
        const resultElement = document.getElementById('fetchResult');
        resultElement.textContent = 'Loading...';
        
        try {
            const response = await fetch('about.html');
            const text = await response.text();
            
            // Show first 500 characters
            const preview = text.substring(0, 500) + (text.length > 500 ? '...' : '');
            resultElement.textContent = `✅ Fetch successful!\n\nStatus: ${response.status}\nContent-Type: ${response.headers.get('content-type')}\n\nPreview:\n${preview}`;
        } catch (error) {
            resultElement.textContent = `❌ Fetch failed:\n${error.message}`;
        }
    });
});

// Add fade-in animation
const style = document.createElement('style');
style.textContent = `
    @keyframes fadeIn {
        from { opacity: 0; transform: translateY(-10px); }
        to { opacity: 1; transform: translateY(0); }
    }
`;
document.head.appendChild(style);

console.log('🚀 ZIPServeKit Demo loaded successfully!');
console.log('Protocol:', window.location.protocol);
console.log('URL:', window.location.href);
