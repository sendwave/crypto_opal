#
# Makefile for G.726 codec plugin
#
# Copyright (C) 2004 Post Increment, All Rights Reserved
#
# The contents of this file are subject to the Mozilla Public License
# Version 1.0 (the "License"); you may not use this file except in
# compliance with the License. You may obtain a copy of the License at
# http://www.mozilla.org/MPL/
#
# Software distributed under the License is distributed on an "AS IS"
# basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See
# the License for the specific language governing rights and limitations
# under the License.
#
# The Original Code is Open H323 library.
#
# The Initial Developer of the Original Code is Post Increment
#
# Contributor(s): ______________________________________.
#
# $Revision: 25724 $
# $Author: rjongbloed $
# $Date: 2011-05-09 21:30:23 -0500 (Mon, 09 May 2011) $
#

BASENAME := g726

SRCDIR := ./g726
SRCS := g726codec.c \
	g711.c \
	$(SRCDIR)/g726_16.c \
	$(SRCDIR)/g726_24.c \
	$(SRCDIR)/g726_32.c \
	$(SRCDIR)/g726_40.c \
	$(SRCDIR)/g72x.c 

INSTALL_DIR := opal-3.10.11/codecs/audio
PLUGINDIR   := /home/lee/sm_for_certify/sanweixinan/crypto_voip_sm/crypto_opal/opal-3.10.11_arm/plugins
include $(PLUGINDIR)/plugin-inc.mak

###########################################
