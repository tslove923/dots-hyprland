#!/usr/bin/env python3
"""
AI Assistant Event Handler
Coordinates wake word detection → voxd activation → AI panel display
"""

import os
import sys
import time
import json
import subprocess
import signal
from pathlib import Path
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler

# Configuration
TRIGGER_FILE = "/tmp/ai-assistant-triggered"
VOXD_SOCKET = os.path.expanduser("~/.config/voxd/voxd.sock")
STATE_FILE = "/tmp/ai-assistant-state.json"

class State:
    IDLE = "idle"
    LISTENING = "listening"
    PROCESSING = "processing"

class AIAssistantHandler(FileSystemEventHandler):
    def __init__(self):
        self.current_state = State.IDLE
        self.voxd_process = None
        self.update_state(State.IDLE)
        
    def update_state(self, new_state):
        """Update assistant state and notify UI"""
        self.current_state = new_state
        
        state_data = {
            'state': new_state,
            'timestamp': time.time()
        }
        
        with open(STATE_FILE, 'w') as f:
            json.dump(state_data, f)
        
        print(f"State changed: {new_state}")
    
    def show_ai_panel(self):
        """Show the AI panel (toggle sidebar)"""
        print("📱 Showing AI panel...")
        
        # Use hyprctl to focus/show the AI panel
        # First, let's try to toggle the sidebar
        # This assumes the panel has a keybind (e.g., Super+A)
        subprocess.run(['hyprctl', 'dispatch', 'exec', 
                       'qdbus org.quickshell /AI toggle'],
                      capture_output=True)
        
        # Alternative: send keybind
        # subprocess.run(['wtype', '-M', 'super', '-P', 'a', '-m', 'super'])
        
    def start_voxd_streaming(self):
        """Start voxd in streaming mode"""
        print("🎙️  Starting voxd streaming...")
        
        # Send command to voxd socket to start recording
        # This is a placeholder - actual voxd API needs investigation
        try:
            # Option 1: Use voxd CLI if available
            subprocess.Popen(['voxd', 'start-stream'], 
                           stdout=subprocess.PIPE,
                           stderr=subprocess.PIPE)
            
            # Option 2: Send signal to voxd process
            # subprocess.run(['pkill', '-USR1', 'voxd'])
            
        except Exception as e:
            print(f"Error starting voxd: {e}")
    
    def stop_voxd_streaming(self):
        """Stop voxd streaming"""
        print("🛑 Stopping voxd streaming...")
        
        try:
            subprocess.run(['voxd', 'stop-stream'],
                          capture_output=True)
        except Exception as e:
            print(f"Error stopping voxd: {e}")
    
    def on_modified(self, event):
        """Handle wake word trigger file changes"""
        if event.src_path == TRIGGER_FILE:
            self.handle_wake_word()
    
    def handle_wake_word(self):
        """Main wake word activation handler"""
        if self.current_state != State.IDLE:
            print("Already active, ignoring wake word")
            return
        
        print("\n🚀 WAKE WORD ACTIVATED!")
        
        # Read trigger data
        try:
            with open(TRIGGER_FILE, 'r') as f:
                trigger_data = json.load(f)
            print(f"Trigger data: {trigger_data}")
        except:
            trigger_data = {}
        
        # 1. Update state to listening
        self.update_state(State.LISTENING)
        
        # 2. Show AI panel with aurora glow
        self.show_ai_panel()
        
        # 3. Start voxd streaming
        self.start_voxd_streaming()
        
        # 4. Set up timeout (auto-stop after 30 seconds)
        # In a real implementation, you'd use threading or async
        time.sleep(30)
        
        # 5. Return to idle
        self.stop_voxd_streaming()
        self.update_state(State.IDLE)
    
    def cleanup(self):
        """Cleanup on exit"""
        if self.voxd_process:
            self.stop_voxd_streaming()
        
        if os.path.exists(STATE_FILE):
            os.unlink(STATE_FILE)

def main():
    print("AI Assistant Event Handler starting...")
    
    handler = AIAssistantHandler()
    
    # Set up file watcher
    observer = Observer()
    observer.schedule(handler, path="/tmp", recursive=False)
    observer.start()
    
    print(f"Watching for triggers at {TRIGGER_FILE}")
    print("Press Ctrl+C to stop")
    
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        print("\nShutting down...")
        observer.stop()
        handler.cleanup()
    
    observer.join()

if __name__ == "__main__":
    main()
