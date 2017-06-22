import glob
import gzip
import os
import shutil
from subprocess import Popen, PIPE

"""
Tools
"""
class colors:
    DEBUG = '\033[92m'
    WARNING = '\033[93m'
    ERROR = '\033[91m'
    ENDC = '\033[0m'
    BOLD = '\033[1m'
    UNDERLINE = '\033[4m'

def debug_log(logstring):
    print(colors.DEBUG + "Hammer:DEBUG: " + colors.ENDC + logstring)

def warning_log(logstring):
    print(colors.WARNING + "Hammer:WARNING: " + logstring + colors.ENDC)

def error_log(logstring):
    print(colors.ERROR + "Hammer:ERROR: " + logstring + colors.ENDC)

def run_script(script, args):
    p = Popen(['/usr/bin/osascript', '-'] + args, stdin=PIPE, stdout=PIPE, stderr = PIPE)
    stdout, stderr = p.communicate(script)
    return stdout.strip()

def newest_directory_in_path(path):
    all_subdirs = [d for d in os.listdir(path) if os.path.isdir(os.path.join(path,d))]
    latest_subdir = None
    latest_time = 0
    for d in all_subdirs:
        current_dir = os.path.join(os.path.join(path,d))
        current_dir_time = os.path.getmtime(current_dir)
        if latest_subdir == None or current_dir_time > latest_time:
            latest_subdir = current_dir
            latest_time = current_dir_time
            continue
    return latest_subdir

"""
"""
def get_edited_file_name():
    """
    Gets the current open file in xcode
    """
    script = '''
        tell application "Xcode"
	       set last_word_in_main_window to (word -1 of (get name of window 1))
	       set current_document to document 1 whose name ends with last_word_in_main_window
	       set current_document_path to path of current_document
	       return current_document_path
        end tell
    '''
    val = run_script(script, [])
    if len(val) > 0:
        debug_log("Currently editing " + val + " in Xcode, we'll try to use that.")
    else:
        error_log("Failed to get current edited document in Xcode! Is Xcode running, and is a source file open?")
    return val

def compile_edited_file(path_to_file):
    """
    Gets the latest Xcode build log.
    Returns path to the dylib
    """
    if (len(path_to_file) > 0):
        debug_log("Trying to compile " + path_to_file)
    else:
        error_log("Nothing to compile!")

    derived_data_path = newest_directory_in_path(os.path.expanduser(os.path.join('~', 'Library', 'Developer', 'Xcode', 'DerivedData')))
    logs_path = os.path.join(derived_data_path, 'Logs', 'Build', '*.xcactivitylog')
    newest_log = min(glob.iglob(logs_path), key=os.path.getctime)

    # the logfile is gzipped
    compile_commands = []
    dylib_output = None
    with gzip.open(newest_log, 'r') as f:
        line = f.read()
        # just one line
        index_of_path = line.rfind(path_to_file)
        left_index = line[:index_of_path].rfind("\r")
        right_index = line[index_of_path:].find("\r")
        raw_command = line[left_index:index_of_path+right_index]
        raw_command = raw_command.replace('-c ' + path_to_file, '-dynamiclib ' + path_to_file)

        # change the output filename
        path_component, file_component = os.path.split(path_to_file)
        file_component = file_component.replace('.m', '.o')
        left_index = raw_command.find('-o ') + 3
        right_index = raw_command.find(file_component) + len(file_component)
        orig_output = raw_command[left_index:right_index]
        dylib_output = orig_output.replace(file_component, file_component.replace('.o', '.dylib'))
        raw_command = raw_command.replace(orig_output, dylib_output)

        # skip missing symbols; they should be in the app too
        raw_command = raw_command + ' -undefined dynamic_lookup'
        compile_commands.append(raw_command.strip())

    compile_commands.append('codesign --force -s "-" ' + dylib_output)

    for command in compile_commands:
        debug_log("Executing compile commands")
        debug_log(command)
        os.system(command)
    return dylib_output

def get_last_used_simulator_application_documents_path():
    """
    Gets the path to the Documents directory of the last used simulator application
    """
    core_path = os.path.expanduser(os.path.join('~', 'Library', 'Developer', 'CoreSimulator', 'Devices'))

    simulator_app_data_path = os.path.join(newest_directory_in_path(core_path), 'data', 'Containers', 'Data', 'Application')
    return os.path.join(newest_directory_in_path(simulator_app_data_path), 'Documents')

# get the edited file
# compile it as a dynamic library
try:
    path_to_dylib = compile_edited_file(get_edited_file_name())
except:
    error_log("Compilation failed!")

# move it to the simulator documents directory
destination_directory = os.path.join(get_last_used_simulator_application_documents_path(), 'hammer')

try:
    # create the destination, if needed
    os.makedirs(destination_directory)
except IOError as e:
    debug_log(e.strerror)
except:
    pass

path_component, file_component = os.path.split(path_to_dylib)
debug_log("Moving new code into " + destination_directory)
new_path = os.path.join(destination_directory, file_component)
try:
    # delete if exists
    os.unlink(new_path)
except:
    pass

try:
    shutil.move(path_to_dylib, new_path)
except IOError as e:
    error_log("Error while installing code into simulator.")
    error_log(e)
except:
    pass
debug_log("...done.")

# profit
