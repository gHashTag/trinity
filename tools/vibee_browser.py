#!/usr/bin/env python3
"""
VIBEE Browser Agent - Real CDP Client
φ² + 1/φ² = 3 | PHOENIX = 999

ny ny browser for witherfandnga through Chrome DevTools Protocol
"""

import json
import subprocess
import time
import requests
import websocket
import base64
import os
import sys

class VIBEEBrowser:
    """VIBEE Browser Agent with CDP"""
    
    PHI = 1.618033988749895
    PHOENIX = 999
    
    def __init__(self, port=9222):
        self.port = port
        self.ws = None
        self.msg_id = 0
        self.chrome_process = None
        
    def start_chrome(self, headless=True):
        """Zapatwithto Chrome with fromladtoabouty"""
        cmd = [
            'chromium-browser',
            f'--remote-debugging-port={self.port}',
            '--no-first-run',
            '--no-default-browser-check',
            '--disable-gpu',
            '--disable-extensions',
            '--disable-popup-blocking',
        ]
        if headless:
            cmd.append('--headless=new')
        
        self.chrome_process = subprocess.Popen(
            cmd,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL
        )
        # Zhdyom launcha Chrome
        for i in range(10):
            time.sleep(1)
            try:
                requests.get(f'http://localhost:{self.port}/json', timeout=1)
                break
            except:
                pass
        print(f"✅ Chrome zapatschen on portat {self.port}")
        return True
        
    def connect(self):
        """Paboutdkeyenande to Chrome by CDP"""
        try:
            # Paboutlatchaem list tseley
            resp = requests.get(f'http://localhost:{self.port}/json')
            targets = resp.json()
            
            # Nakhaboutdandm withtranandtsat
            page_target = None
            for t in targets:
                if t.get('type') == 'page':
                    page_target = t
                    break
            
            if not page_target:
                # Saboutzdayom naboutinatyu withtranandtsat
                resp = requests.put(f'http://localhost:{self.port}/json/new')
                page_target = resp.json()
            
            ws_url = page_target['webSocketDebuggerUrl']
            self.ws = websocket.create_connection(ws_url)
            print(f"✅ Paboutdkeyenabout to CDP: {ws_url[:50]}...")
            
            # Vkeyaem domainy
            self._send('Page.enable')
            self._send('DOM.enable')
            self._send('Runtime.enable')
            self._send('Network.enable')
            
            return True
        except Exception as e:
            print(f"❌ Error underkeyenandya: {e}")
            return False
    
    def _send(self, method, params=None):
        """Otpraintoa CDP toaboutmandy"""
        self.msg_id += 1
        msg = {
            'id': self.msg_id,
            'method': method,
            'params': params or {}
        }
        self.ws.send(json.dumps(msg))
        
        # Zhdyom answer
        while True:
            resp = json.loads(self.ws.recv())
            if resp.get('id') == self.msg_id:
                if 'error' in resp:
                    print(f"⚠️ CDP Error: {resp['error']}")
                return resp.get('result', {})
            # Praboutpatwithtoaem withaboutytandya
    
    def goto(self, url):
        """Perekhaboutd on URL"""
        print(f"🌐 Perekhaboutd on: {url}")
        result = self._send('Page.navigate', {'url': url})
        time.sleep(2)  # Zhdyom zagratztoand
        return result
    
    def get_title(self):
        """Paboutlatchandt zagaboutlaboutinaboutto withtranandtsy"""
        result = self._send('Runtime.evaluate', {
            'expression': 'document.title'
        })
        return result.get('result', {}).get('value', '')
    
    def get_url(self):
        """Paboutlatchandt thosetoatschandy URL"""
        result = self._send('Runtime.evaluate', {
            'expression': 'window.location.href'
        })
        return result.get('result', {}).get('value', '')
    
    def screenshot(self, path='screenshot.png'):
        """Sdelat withtorandnshfrom"""
        result = self._send('Page.captureScreenshot', {'format': 'png'})
        if 'data' in result:
            with open(path, 'wb') as f:
                f.write(base64.b64decode(result['data']))
            print(f"📸 Storandnshfrom withaboutkhranyon: {path}")
            return path
        return None
    
    def click(self, selector):
        """Klandto by withelewhorat"""
        # Nakhaboutdandm element
        doc = self._send('DOM.getDocument')
        root_id = doc['root']['nodeId']
        
        result = self._send('DOM.querySelector', {
            'nodeId': root_id,
            'selector': selector
        })
        
        node_id = result.get('nodeId')
        if not node_id:
            print(f"❌ Element ne onyden: {selector}")
            return False
        
        # Paboutlatchaem toaboutaboutrdandonty
        box = self._send('DOM.getBoxModel', {'nodeId': node_id})
        if 'model' not in box:
            print(f"❌ Ne atdalaboutwith bylatchandt toaboutaboutrdandonty: {selector}")
            return False
        
        content = box['model']['content']
        x = (content[0] + content[2]) / 2
        y = (content[1] + content[5]) / 2
        
        # Klandtoaem
        self._send('Input.dispatchMouseEvent', {
            'type': 'mousePressed',
            'x': x, 'y': y,
            'button': 'left',
            'clickCount': 1
        })
        self._send('Input.dispatchMouseEvent', {
            'type': 'mouseReleased',
            'x': x, 'y': y,
            'button': 'left',
            'clickCount': 1
        })
        
        print(f"🖱️ Klandto by: {selector} ({x:.0f}, {y:.0f})")
        return True
    
    def type_text(self, selector, text):
        """Input texta in field"""
        # Klandtoaem for fabouttoatwitha
        self.click(selector)
        time.sleep(0.3)
        
        # Inputandm text
        for char in text:
            self._send('Input.dispatchKeyEvent', {
                'type': 'keyDown',
                'text': char
            })
            self._send('Input.dispatchKeyEvent', {
                'type': 'keyUp',
                'text': char
            })
        
        print(f"⌨️ Vinedenabout: {text}")
        return True
    
    def press_enter(self):
        """Nazhat Enter"""
        self._send('Input.dispatchKeyEvent', {
            'type': 'keyDown',
            'key': 'Enter',
            'code': 'Enter',
            'windowsVirtualKeyCode': 13
        })
        self._send('Input.dispatchKeyEvent', {
            'type': 'keyUp',
            'key': 'Enter',
            'code': 'Enter',
            'windowsVirtualKeyCode': 13
        })
        print("⏎ Enter")
        return True
    
    def get_text(self, selector):
        """Paboutlatchandt text elementa"""
        result = self._send('Runtime.evaluate', {
            'expression': f'document.querySelector("{selector}")?.innerText || ""'
        })
        return result.get('result', {}).get('value', '')
    
    def get_html(self):
        """Paboutlatchandt HTML withtranandtsy"""
        result = self._send('Runtime.evaluate', {
            'expression': 'document.documentElement.outerHTML'
        })
        return result.get('result', {}).get('value', '')
    
    def execute_js(self, script):
        """Vybylnandt JavaScript"""
        result = self._send('Runtime.evaluate', {
            'expression': script,
            'returnByValue': True
        })
        return result.get('result', {}).get('value')
    
    def close(self):
        """Zatoryt browser"""
        if self.ws:
            self.ws.close()
        if self.chrome_process:
            self.chrome_process.terminate()
        print("👋 Braatzer zatoryt")


def demo():
    """Demaboutnwithtratsandya rabfromy VIBEE Browser"""
    print("=" * 60)
    print("  VIBEE Browser Agent - φ² + 1/φ² = 3")
    print("=" * 60)
    
    browser = VIBEEBrowser()
    
    try:
        # Zapatwithtoaem Chrome
        browser.start_chrome(headless=True)
        
        # Paboutdkeyaemwithya
        if not browser.connect():
            return
        
        # Perekhaboutdandm on withtranandtsat
        browser.goto('https://example.com')
        
        # Paboutlatchaem andnformtsandyu
        title = browser.get_title()
        url = browser.get_url()
        
        print(f"\n📄 Zagaboutlaboutinaboutto: {title}")
        print(f"🔗 URL: {url}")
        
        # Storandnshfrom
        browser.screenshot('/tmp/vibee_screenshot.png')
        
        # Paboutlatchaem text
        text = browser.get_text('h1')
        print(f"📝 H1: {text}")
        
        print("\n✅ VIBEE Browser rabfromaet!")
        print(f"φ² + 1/φ² = {VIBEEBrowser.PHI**2 + 1/VIBEEBrowser.PHI**2:.1f}")
        
    finally:
        browser.close()


if __name__ == '__main__':
    if len(sys.argv) > 1 and sys.argv[1] == 'demo':
        demo()
    else:
        print("Usage: python vibee_browser.py demo")
        print("       python vibee_browser.py")
