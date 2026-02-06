#!/usr/bin/env python3
"""
Audio Resource Manager
Coordinates microphone access between wake word detector and voxd
Prevents conflicts and optimizes power usage
"""

import os
import time
import json
from pathlib import Path
from enum import Enum

STATE_FILE = "/tmp/ai-assistant-audio-state.json"
LOCK_FILE = "/tmp/ai-assistant-audio.lock"

class AudioState(Enum):
    IDLE = "idle"                    # Nothing using mic
    WAKE_WORD_LISTENING = "wake_word_listening"  # Wake word detector active
    VOXD_RECORDING = "voxd_recording"           # voxd is recording
    PAUSED = "paused"                           # Wake word paused for voxd

class AudioResourceManager:
    """
    Manages shared microphone access between components.
    
    Strategy:
    - Wake word detector: Always listening EXCEPT when voxd is active
    - voxd: Only records when triggered, has priority
    - Coordination via shared state file
    """
    
    def __init__(self, component_name: str):
        self.component = component_name
        self.state_file = Path(STATE_FILE)
        self.lock_file = Path(LOCK_FILE)
        
    def _read_state(self) -> dict:
        """Read current audio state"""
        try:
            if self.state_file.exists():
                with open(self.state_file, 'r') as f:
                    return json.load(f)
        except:
            pass
        
        return {
            'state': AudioState.IDLE.value,
            'owner': None,
            'timestamp': 0
        }
    
    def _write_state(self, state: AudioState, owner: str = None):
        """Update audio state"""
        data = {
            'state': state.value,
            'owner': owner or self.component,
            'timestamp': time.time()
        }
        
        with open(self.state_file, 'w') as f:
            json.dump(data, f)
    
    def request_access(self, blocking: bool = False, timeout: float = 5.0) -> bool:
        """
        Request microphone access.
        
        Args:
            blocking: Wait if another component has priority
            timeout: Max wait time in seconds
        
        Returns:
            True if access granted, False otherwise
        """
        start = time.time()
        
        while True:
            state = self._read_state()
            current_state = state.get('state')
            
            # Wake word detector: Can run if idle or already listening
            if self.component == 'wake_word':
                if current_state in [AudioState.IDLE.value, AudioState.WAKE_WORD_LISTENING.value]:
                    self._write_state(AudioState.WAKE_WORD_LISTENING)
                    return True
                elif current_state == AudioState.VOXD_RECORDING.value:
                    # voxd has priority, wake word should pause
                    if not blocking:
                        return False
                    # Wait for voxd to finish
                    time.sleep(0.1)
                    if time.time() - start > timeout:
                        return False
                    continue
            
            # voxd: Has priority, can interrupt wake word
            elif self.component == 'voxd':
                if current_state in [AudioState.IDLE.value, AudioState.WAKE_WORD_LISTENING.value]:
                    self._write_state(AudioState.VOXD_RECORDING)
                    return True
                elif current_state == AudioState.VOXD_RECORDING.value:
                    # Already recording
                    return True
            
            # Unknown component
            else:
                if current_state == AudioState.IDLE.value:
                    self._write_state(AudioState.IDLE, self.component)
                    return True
                elif not blocking:
                    return False
            
            time.sleep(0.1)
            if time.time() - start > timeout:
                return False
    
    def release_access(self):
        """Release microphone access"""
        state = self._read_state()
        
        if state.get('owner') == self.component:
            # Return to idle or wake word listening
            if self.component == 'voxd':
                # Let wake word detector resume
                self._write_state(AudioState.WAKE_WORD_LISTENING, 'wake_word')
            else:
                self._write_state(AudioState.IDLE)
    
    def should_pause(self) -> bool:
        """Check if this component should pause (yield to higher priority)"""
        if self.component != 'wake_word':
            return False
        
        state = self._read_state()
        return state.get('state') == AudioState.VOXD_RECORDING.value
    
    def get_state(self) -> dict:
        """Get current audio state"""
        return self._read_state()

# Convenience functions
def can_use_microphone(component: str) -> bool:
    """Quick check if component can use microphone"""
    manager = AudioResourceManager(component)
    return manager.request_access(blocking=False)

def notify_voxd_start():
    """Notify that voxd is starting to record (pauses wake word)"""
    manager = AudioResourceManager('voxd')
    manager.request_access()

def notify_voxd_stop():
    """Notify that voxd finished recording (resumes wake word)"""
    manager = AudioResourceManager('voxd')
    manager.release_access()

def get_audio_state() -> str:
    """Get current audio state"""
    manager = AudioResourceManager('system')
    return manager.get_state().get('state', 'idle')

if __name__ == "__main__":
    # Test the manager
    import sys
    
    if len(sys.argv) < 2:
        print("Usage: audio_manager.py [wake_word|voxd|status]")
        sys.exit(1)
    
    cmd = sys.argv[1]
    
    if cmd == "status":
        manager = AudioResourceManager('system')
        state = manager.get_state()
        print(f"Current state: {state['state']}")
        print(f"Owner: {state['owner']}")
        print(f"Timestamp: {state['timestamp']}")
    
    elif cmd == "wake_word":
        manager = AudioResourceManager('wake_word')
        if manager.request_access():
            print("✅ Wake word detector can use microphone")
        else:
            print("❌ Microphone busy (voxd recording)")
    
    elif cmd == "voxd":
        manager = AudioResourceManager('voxd')
        if manager.request_access():
            print("✅ voxd has microphone access")
            print("   (wake word detector paused)")
        else:
            print("❌ Could not get microphone access")
    
    elif cmd == "release":
        component = sys.argv[2] if len(sys.argv) > 2 else 'voxd'
        manager = AudioResourceManager(component)
        manager.release_access()
        print(f"✅ {component} released microphone")
