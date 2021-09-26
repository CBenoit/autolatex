#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
# Copyright (C) 1998-2021 Stephane Galland <galland@arakhne.org>
#
# This program is free library; you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as
# published by the Free Software Foundation; either version 3 of the
# License, or any later version.
#
# This library is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library; see the file COPYING.  If not,
# write to the Free Software Foundation, Inc., 59 Temple Place - Suite
# 330, Boston, MA 02111-1307, USA.

import unittest
import logging

from autolatex2.config import view

class TestViewConfig(unittest.TestCase):

	def __init__(self, *args, **kwargs):
		super().__init__(*args, **kwargs)
		self.__config = None

	def setUp(self):
		logging.getLogger().setLevel(logging.CRITICAL)
		self.__config = view.ViewerConfig()

	@property
	def config(self) -> view.ViewerConfig:
		return self.__config

	def test_get_view(self):
		self.assertFalse(self.config.view)

	def test_set_view(self):
		self.config.view = False
		self.assertFalse(self.config.view)		
		self.config.view = True
		self.assertTrue(self.config.view)		
		self.config.view = False
		self.assertFalse(self.config.view)		
		self.config.view = True
		self.assertTrue(self.config.view)		



if __name__ == '__main__':
    unittest.main()

