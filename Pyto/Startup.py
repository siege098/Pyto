import sys
import os

sys.path.insert(0, os.path.expanduser("~/Library/pylib"))
sys.path.insert(0, os.path.expanduser("~/Documents"))
sys.path.insert(0, os.path.expanduser("~/Documents/modules"))

import io
import console as Pyto
import code
import PytoClasses
from importlib.machinery import SourceFileLoader
import importlib
import threading

PytoClasses.Python.shared.version = sys.version

# MARK: - Input

def askForInput(prompt=None):
    if (threading.currentThread() in Pyto.ignoredThreads):
        return ""
    else:
        return Pyto.input(prompt)


__builtins__.input = askForInput

# MARK: - Output

oldStdout = sys.__stdout__

class Reader:
    
    @property
    def buffer(self):
        return self._buffer
    
    @property
    def encoding(self):
        return "utf-8"
    
    @property
    def closed(self):
        return False
    
    def __init__(self):
        pass
    
    def isatty(self):
        return False
    
    def writable(self):
        return True
    
    def flush(self):
        pass
    
    def write(self, txt):
        
        if (threading.currentThread() in Pyto.ignoredThreads):
            return
        
        if txt.__class__.__name__ == 'str':
            oldStdout.write(txt)
            Pyto.print(txt, end="")
        elif txt.__class__.__name__ == 'bytes':
            text = txt.decode()
            oldStdout.write(text)
            Pyto.print(text, end="")

standardOutput = Reader()
standardOutput._buffer = io.BufferedWriter(standardOutput)

standardError = Reader()
standardError._buffer = io.BufferedWriter(standardError)

sys.stdout = standardOutput
sys.stderr = standardError

# MARK: - REPL

interact = code.interact
def newInteract():
    PytoClasses.Python.shared.isREPLRunning = True
    interact()
code.interact = newInteract

# MARK: - NumPy

class NumpyImporter(object):
    def find_module(self, fullname, mpath=None):
        if fullname in ('numpy.core.multiarray', 'numpy.core.umath', 'numpy.fft.fftpack_lite', 'numpy.linalg._umath_linalg', 'numpy.linalg.lapack_lite', 'numpy.random.mtrand'):
            return self
                    
        return

    def load_module(self, fullname):
        f = '__' + fullname.replace('.', '_')
        mod = sys.modules.get(f)
        if mod is None:
            mod = importlib.__import__(f)
            sys.modules[fullname] = mod
            return mod

        return mod

sys.meta_path.append(NumpyImporter())

# MARK: - Pandas

# TODO: Add Pandas
'''class PandasImporter(object):
    def find_module(self, fullname, mpath=None):
        if fullname in ('pandas.hashtable', 'pandas.lib'):
            return self
        
        return
    
    def load_module(self, fullname):
        f = '__' + fullname.replace('.', '_')
        mod = sys.modules.get(f)
        if mod is None:
            mod = importlib.__import__(f)
            sys.modules[fullname] = mod
            return mod
        
        return mod

sys.meta_path.append(PandasImporter())'''

# MARK: - Run script

try:
    SourceFileLoader("main", "%@").load_module()
except Exception as e:
    print(e)
