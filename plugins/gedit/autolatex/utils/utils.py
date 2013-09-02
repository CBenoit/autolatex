# autolatex/utils/utils.py
# Copyright (C) 2013  Stephane Galland <galland@arakhne.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; see the file COPYING.  If not, write to
# the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
# Boston, MA 02111-1307, USA.

#---------------------------------
# IMPORTS
#---------------------------------

# Import standard python libs
import os
import subprocess
import ConfigParser
import StringIO
import gettext
# Include the Glib, Gtk and Gedit libraries
from gi.repository import Gio, Gtk

#---------------------------------
# UTILITY FUNCTION
#---------------------------------

# Search an executable in the PATH
def which(cmd):
  # can't search the path if a directory is specified
  assert not os.path.dirname(cmd)
  extensions = os.environ.get("PATHEXT", "").split(os.pathsep)
  for directory in os.environ.get("PATH", "").split(os.pathsep):
    base = os.path.join(directory, cmd)
    options = [base] + [(base + ext) for ext in extensions]
    for filename in options:
      if os.path.exists(filename):
        return filename
  return None


#---------------------------------
# CONSTANTS
#---------------------------------

# Level of verbosity of AutoLaTeX
DEFAULT_LOG_LEVEL = '--quiet'

# String that is representing an empty string for the AutoLaTeX backend.
CONFIG_EMPTY_VALUE = '<<<<empty>>>>'

# Plugin path
_p = Gio.File.new_for_path(os.getcwd())
AUTOLATEX_PLUGIN_PATH = os.path.join(os.path.dirname(__file__), 'utils.py') # To support .py and .pyc
AUTOLATEX_PLUGIN_PATH = _p.resolve_relative_path(AUTOLATEX_PLUGIN_PATH).get_path()
while os.path.islink(AUTOLATEX_PLUGIN_PATH):
	_p = Gio.File.new_for_path(os.path.dirname(AUTOLATEX_PLUGIN_PATH))
	AUTOLATEX_PLUGIN_PATH = _p.resolve_relative_path(os.readlink(AUTOLATEX_PLUGIN_PATH)).get_path()
AUTOLATEX_PLUGIN_PATH = os.path.dirname(os.path.dirname(AUTOLATEX_PLUGIN_PATH))

# PO path
AUTOLATEX_PO_PATH = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(AUTOLATEX_PLUGIN_PATH))), 'po')
if not os.path.exists(os.path.join(AUTOLATEX_PO_PATH, 'fr', 'LC_MESSAGES', 'geditautolatex.mo')):
	AUTOLATEX_PO_PATH = None # Default locale path

# PM path
AUTOLATEX_PM_PATH = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(AUTOLATEX_PLUGIN_PATH))), 'pm')

# Binary file of AutoLaTeX
# Use the development versions of the scripts
AUTOLATEX_BINARY = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(AUTOLATEX_PLUGIN_PATH))), 'autolatex.pl')
if not os.path.exists(AUTOLATEX_BINARY):
	AUTOLATEX_BINARY = which('autolatex')
DEFAULT_AUTOLATEX_BINARY = AUTOLATEX_BINARY
AUTOLATEX_BACKEND_BINARY = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(AUTOLATEX_PLUGIN_PATH))), 'autolatex-backend.pl')
if not os.path.exists(AUTOLATEX_BACKEND_BINARY):
	AUTOLATEX_BACKEND_BINARY = which('autolatex-backend')
DEFAULT_AUTOLATEX_BACKEND_BINARY = AUTOLATEX_BACKEND_BINARY

# Path where the icons are installed
TOOLBAR_ICON_PATH = os.path.join(AUTOLATEX_PLUGIN_PATH, 'icons', '24')
NOTEBOOK_ICON_PATH = os.path.join(AUTOLATEX_PLUGIN_PATH, 'icons', '16')
TABLE_ICON_PATH = os.path.join(AUTOLATEX_PLUGIN_PATH, 'icons', '16')



def init_internationalization():
	gettext.bindtextdomain('geditautolatex', AUTOLATEX_PO_PATH)
	gettext.textdomain('geditautolatex')

def make_toolbar_icon_path(name):
	return os.path.join(TOOLBAR_ICON_PATH, name)

def make_notebook_icon_path(name):
	return os.path.join(NOTEBOOK_ICON_PATH, name)

def make_table_icon_path(name):
	return os.path.join(TABLE_ICON_PATH, name)



def backend_get_translators(directory):
	os.chdir(directory)
	process = subprocess.Popen( [AUTOLATEX_BACKEND_BINARY, 'get', 'translators'], stdout=subprocess.PIPE )
	data = process.communicate()[0]
	string_in = StringIO.StringIO(data)
	config = ConfigParser.ConfigParser()
	config.readfp(string_in)
	string_in.close()
	return config

def backend_get_loads(directory):
	os.chdir(directory)
	process = subprocess.Popen( [AUTOLATEX_BACKEND_BINARY, 'get', 'loads', ], stdout=subprocess.PIPE )
	data = process.communicate()[0]
	string_in = StringIO.StringIO(data)
	config = ConfigParser.ConfigParser()
	config.readfp(string_in)
	string_in.close()
	return config

def backend_get_configuration(directory, level, section):
	os.chdir(directory)
	process = subprocess.Popen( [AUTOLATEX_BACKEND_BINARY, 'get', 'config', level, section], stdout=subprocess.PIPE )
	data = process.communicate()[0]
	string_in = StringIO.StringIO(data)
	config = ConfigParser.ConfigParser()
	config.readfp(string_in)
	string_in.close()
	return config

def backend_get_images(directory):
	os.chdir(directory)
	process = subprocess.Popen( [AUTOLATEX_BACKEND_BINARY, 'get', 'images'], stdout=subprocess.PIPE )
	data = process.communicate()[0]
	string_in = StringIO.StringIO(data)
	config = ConfigParser.ConfigParser()
	config.readfp(string_in)
	string_in.close()
	return config

def backend_set_loads(directory, load_config):
	os.chdir(directory)
	string_out = StringIO.StringIO()
	load_config.write(string_out)
	process = subprocess.Popen( [AUTOLATEX_BACKEND_BINARY, 'set', 'loads', ], stdin=subprocess.PIPE)
	process.communicate(input=string_out.getvalue())
	string_out.close()
	return process.returncode == 0

def backend_set_configuration(directory, level, settings):
	os.chdir(directory)
	string_out = StringIO.StringIO()
	settings.write(string_out)
	process = subprocess.Popen( [AUTOLATEX_BACKEND_BINARY, 'set', 'config', level, 'false' ], stdin=subprocess.PIPE)
	process.communicate(input=string_out.getvalue())
	string_out.close()
	return process.returncode == 0

def backend_set_images(directory, settings):
	os.chdir(directory)
	string_out = StringIO.StringIO()
	settings.write(string_out)
	process = subprocess.Popen( [AUTOLATEX_BACKEND_BINARY, 'set', 'images', 'false' ], stdin=subprocess.PIPE)
	process.communicate(input=string_out.getvalue())
	string_out.close()
	return process.returncode == 0


def first_of(*values):
	for value in values:
		if value is not None:
			return value
	return None

def get_autolatex_user_config_directory():
	if os.name == 'posix':
		return os.path.join(os.path.expanduser("~"), ".autolatex")
	elif os.name == 'nt':
		return  os.path.join(os.path.expanduser("~"),"Local Settings","Application Data","autolatex")
	else:
		return os.path.join(os.path.expanduser("~"), "autolatex")

def get_autolatex_user_config_file():
	directory = get_autolatex_user_config_directory()
	if os.path.isdir(directory):
		return os.path.join(directory, 'autolatex.conf')
	if os.name == 'posix':
		return os.path.join(os.path.expanduser("~"), ".autolatex")
	elif os.name == 'nt':
		return  os.path.join(os.path.expanduser("~"),"Local Settings","Application Data","autolatex.conf")
	else:
		return os.path.join(os.path.expanduser("~"), "autolatex.conf")

def get_insert_index_dichotomic(list_store, column, data):
	f = 0
	l = list_store.iter_n_children(None) - 1
	while l >= f:
		c = (f+l) / 2
		path = Gtk.TreePath(c)
		d = list_store[path][column]
		cmpt = (data > d) - (data < d)
		if cmpt == 0:
			return -1
		elif cmpt < 0:
			l = c-1
		else:
			f = c+1
	return f

