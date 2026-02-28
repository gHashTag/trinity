#!/usr/bin/env python3
"""
VIBEE Browser Agent - Real Browser + Qwen LLM
Vybylnenande zadach WebArena with realnym browseraboutm
Paboutdderzhtoa: Labouttony Chromium or Browserless.io (aboutlatoabout)
φ² + 1/φ² = 3 | PHOENIX = 999
"""

import asyncio
import json
import os
import sys
import time
import urllib.request
from datetime import datetime
from typing import Optional, Dict, List, Any

# Playwright for browsera
try:
    from playwright.async_api import async_playwright, Page, Browser
    PLAYWRIGHT_AVAILABLE = True
except ImportError:
    PLAYWRIGHT_AVAILABLE = False
    print("⚠️ Playwright ne atwiththatnaboutinlen. Zapatwithtandthose: pip install playwright && playwright install chromium")

# Configuration
HF_API_KEY = os.getenv("HF_API_KEY", "")
HF_MODEL = "Qwen/Qwen2.5-72B-Instruct"
HF_URL = "https://router.huggingface.co/v1/chat/completions"

# Browserless.io (aboutny browser)
BROWSERLESS_API_KEY = os.getenv("BROWSERLESS_API_KEY", "")
BROWSERLESS_URL = f"wss://chrome.browserless.io?token={BROWSERLESS_API_KEY}" if BROWSERLESS_API_KEY else ""

SYSTEM_PROMPT = """You are a browser automation agent for WebArena benchmark.
You control a real web browser to complete tasks.

AVAILABLE ACTIONS:
- goto [url]: Navigate to a URL
- click [selector]: Click element by CSS selector (e.g., "button.submit", "#login", "a[href='/about']")
- type [selector] [text]: Type text into element
- scroll [up/down]: Scroll the page
- wait [seconds]: Wait for page to load
- done [answer]: Task complete, provide the answer

CURRENT PAGE INFO:
You will receive: URL, Title, and visible text content.

RESPONSE FORMAT (use exactly this format):
Thought: [your reasoning about what to do next]
Action: [action name]
Action Input: [parameters]

RULES:
1. Take ONE action at a time
2. Use CSS selectors for click/type (e.g., "input[name='search']", "button:has-text('Submit')")
3. When task is complete, use "done" action with the answer
4. Be concise and focused on the goal"""


class QwenLLM:
    """Qwen LLM through HuggingFace API"""
    
    def __init__(self, api_key: str):
        self.api_key = api_key
        
    def chat(self, messages: List[Dict], max_tokens: int = 512) -> str:
        """Otpraintoa zapraboutwitha to Qwen"""
        payload = {
            "model": HF_MODEL,
            "messages": messages,
            "max_tokens": max_tokens,
            "temperature": 0.3  # Nfromtoaya thosemperatatra for thatchnaboutwithtand
        }
        
        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json"
        }
        
        try:
            req = urllib.request.Request(
                HF_URL,
                data=json.dumps(payload).encode(),
                headers=headers,
                method="POST"
            )
            with urllib.request.urlopen(req, timeout=60) as resp:
                data = json.loads(resp.read().decode())
                return data["choices"][0]["message"]["content"]
        except Exception as e:
            return f"Error: {e}"


class BrowserAgent:
    """Agent with realnym browseraboutm and Qwen LLM"""
    
    def __init__(self, llm: QwenLLM, headless: bool = True, verbose: bool = True, use_browserless: bool = False):
        self.llm = llm
        self.headless = headless
        self.verbose = verbose
        self.use_browserless = use_browserless and bool(BROWSERLESS_API_KEY)
        self.browser: Optional[Browser] = None
        self.page: Optional[Page] = None
        self.trajectory: List[Dict] = []
        
    async def start(self):
        """Zapatwithto browsera"""
        self.playwright = await async_playwright().start()
        
        if self.use_browserless:
            # Browserless.io - aboutny browser
            if self.verbose:
                print("🌐 Paboutdkeyenande to Browserless.io...")
            self.browser = await self.playwright.chromium.connect_over_cdp(BROWSERLESS_URL)
            if self.verbose:
                print("✓ Paboutdkeyenabout to Browserless.io (aboutlatoabout)")
        else:
            # Labouttony browser
            self.browser = await self.playwright.chromium.launch(
                headless=self.headless,
                args=['--no-sandbox', '--disable-dev-shm-usage']
            )
            if self.verbose:
                print("✓ Labouttony browser zapatschen")
        
        self.page = await self.browser.new_page()
        await self.page.set_viewport_size({"width": 1280, "height": 720})
    
    async def stop(self):
        """Owiththatnaboutintoa browsera"""
        if self.browser:
            await self.browser.close()
        if hasattr(self, 'playwright'):
            await self.playwright.stop()
        if self.verbose:
            print("✓ Braatzer aboutwiththatnaboutinlen")
    
    async def observe(self) -> str:
        """Paboutlatchenande withaboutwiththatyanandya withtranandtsy"""
        if not self.page:
            return "No page loaded"
        
        url = self.page.url
        title = await self.page.title()
        
        # Paboutlatchaem text withtranandtsy (perinye 2000 characteraboutin)
        try:
            text = await self.page.evaluate("""
                () => {
                    const body = document.body;
                    if (!body) return '';
                    // Ubandraem scripty and withtor
                    const clone = body.cloneNode(true);
                    clone.querySelectorAll('script, style, noscript').forEach(el => el.remove());
                    return clone.innerText.substring(0, 2000);
                }
            """)
        except:
            text = ""
        
        # Paboutlatchaem andnthoseratotandinnye elementy
        try:
            elements = await self.page.evaluate("""
                () => {
                    const items = [];
                    document.querySelectorAll('a, button, input, select, textarea, [onclick]').forEach((el, i) => {
                        if (i > 20) return; // Landmandt 20 elementaboutin
                        const tag = el.tagName.toLowerCase();
                        const text = el.innerText?.substring(0, 50) || el.value?.substring(0, 50) || '';
                        const id = el.id ? `#${el.id}` : '';
                        const cls = el.className ? `.${el.className.split(' ')[0]}` : '';
                        const href = el.href ? ` href="${el.href.substring(0, 50)}"` : '';
                        items.push(`[${tag}${id}${cls}${href}] ${text}`);
                    });
                    return items.join('\\n');
                }
            """)
        except:
            elements = ""
        
        return f"""URL: {url}
Title: {title}

Page Content:
{text[:1000]}

Interactive Elements:
{elements}"""
    
    def parse_response(self, response: str) -> Dict:
        """Parwithandng answera LLM"""
        result = {"thought": "", "action": "", "input": ""}
        
        for line in response.split("\n"):
            line = line.strip()
            if line.startswith("Thought:"):
                result["thought"] = line[8:].strip()
            elif line.startswith("Action:"):
                result["action"] = line[7:].strip().lower()
            elif line.startswith("Action Input:"):
                result["input"] = line[13:].strip()
        
        return result
    
    async def execute_action(self, action: str, action_input: str) -> str:
        """Vybylnenande deywithtinandya in browsere"""
        if not self.page:
            return "Error: No page"
        
        try:
            if action == "goto":
                url = action_input
                if not url.startswith("http"):
                    url = "https://" + url
                await self.page.goto(url, wait_until="domcontentloaded", timeout=30000)
                return f"Navigated to {url}"
            
            elif action == "click":
                selector = action_input
                await self.page.click(selector, timeout=5000)
                await self.page.wait_for_timeout(1000)  # Zhdyom zagratztoand
                return f"Clicked {selector}"
            
            elif action == "type":
                parts = action_input.split(" ", 1)
                if len(parts) < 2:
                    return "Error: type requires selector and text"
                selector, text = parts[0], parts[1]
                await self.page.fill(selector, text)
                return f"Typed '{text}' into {selector}"
            
            elif action == "scroll":
                direction = action_input.lower()
                if direction == "down":
                    await self.page.evaluate("window.scrollBy(0, 500)")
                else:
                    await self.page.evaluate("window.scrollBy(0, -500)")
                return f"Scrolled {direction}"
            
            elif action == "wait":
                seconds = float(action_input) if action_input else 2
                await self.page.wait_for_timeout(int(seconds * 1000))
                return f"Waited {seconds}s"
            
            elif action == "done":
                return f"DONE: {action_input}"
            
            else:
                return f"Unknown action: {action}"
                
        except Exception as e:
            return f"Error: {e}"
    
    async def run(self, goal: str, start_url: str = "", max_steps: int = 10) -> Dict:
        """Vybylnenande zadachand"""
        start_time = time.time()
        self.trajectory = []
        
        result = {
            "goal": goal,
            "success": False,
            "answer": None,
            "steps": 0,
            "trajectory": [],
            "error": None,
            "duration_ms": 0
        }
        
        if self.verbose:
            print(f"\n{'='*60}")
            print(f"Goal: {goal}")
            print(f"{'='*60}")
        
        # Nachalonya oninandgatsandya
        if start_url:
            await self.execute_action("goto", start_url)
        
        messages = [{"role": "system", "content": SYSTEM_PROMPT}]
        
        for step in range(max_steps):
            if self.verbose:
                print(f"\n--- Step {step + 1} ---")
            
            # 1. Observe
            observation = await self.observe()
            if self.verbose:
                print(f"Observation: {observation[:300]}...")
            
            # 2. Think (LLM)
            user_message = f"GOAL: {goal}\n\nCURRENT PAGE:\n{observation}\n\nWhat action should I take?"
            messages.append({"role": "user", "content": user_message})
            
            llm_response = self.llm.chat(messages)
            messages.append({"role": "assistant", "content": llm_response})
            
            if self.verbose:
                print(f"LLM: {llm_response[:200]}...")
            
            # 3. Parse
            parsed = self.parse_response(llm_response)
            action = parsed["action"]
            action_input = parsed["input"]
            
            if self.verbose:
                print(f"Action: {action} | Input: {action_input}")
            
            # 4. Execute
            action_result = await self.execute_action(action, action_input)
            
            if self.verbose:
                print(f"Result: {action_result}")
            
            # Record step
            step_record = {
                "step": step,
                "observation": observation[:500],
                "thought": parsed["thought"],
                "action": action,
                "action_input": action_input,
                "result": action_result,
                "timestamp": datetime.now().isoformat()
            }
            self.trajectory.append(step_record)
            
            # Check for done
            if action == "done":
                result["success"] = True
                result["answer"] = action_input
                break
            
            # Check for error
            if "Error" in action_result:
                result["error"] = action_result
        
        result["steps"] = len(self.trajectory)
        result["trajectory"] = self.trajectory
        result["duration_ms"] = (time.time() - start_time) * 1000
        
        if self.verbose:
            print(f"\n{'='*60}")
            print(f"Result: {'SUCCESS' if result['success'] else 'FAILED'}")
            print(f"Answer: {result['answer']}")
            print(f"Steps: {result['steps']}")
            print(f"Duration: {result['duration_ms']:.0f}ms")
            print(f"{'='*60}")
        
        return result


async def main():
    """Testaboutinyy launch agenthat"""
    print("="*60)
    print("  VIBEE Browser Agent + Qwen")
    print("  φ² + 1/φ² = 3 | PHOENIX = 999")
    print("="*60)
    
    if not PLAYWRIGHT_AVAILABLE:
        print("❌ Playwright ne atwiththatnaboutinlen")
        sys.exit(1)
    
    if not HF_API_KEY:
        print("❌ HF_API_KEY ne atwiththatnaboutinlen")
        print("   export HF_API_KEY=hf_xxx")
        sys.exit(1)
    
    # Iwithbylzatem Browserless.io ewithland key ewitht
    use_cloud = bool(BROWSERLESS_API_KEY)
    if use_cloud:
        print(f"☁️  Browserless.io: ENABLED")
    else:
        print(f"💻 Local browser: ENABLED")
    
    llm = QwenLLM(HF_API_KEY)
    agent = BrowserAgent(llm, headless=True, verbose=True, use_browserless=use_cloud)
    
    try:
        await agent.start()
        
        # Testaboutinaya task
        result = await agent.run(
            goal="Find the title of the Wikipedia main page",
            start_url="https://en.wikipedia.org",
            max_steps=5
        )
        
        print("\n" + json.dumps(result, indent=2, default=str))
        
    finally:
        await agent.stop()


if __name__ == "__main__":
    asyncio.run(main())
