#
# Makefile for THEORA
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
# Contributor(s): Matthias Schneider (ma30002000@yahoo.de)
#
# $Revision: 25962 $
# $Author: rjongbloed $
# $Date: 2011-06-02 20:10:44 -0500 (Thu, 02 Jun 2011) $
#

BASENAME=theora

COMMONDIR := ../common
SRCDIR    := .
SRCS      := theora_frame.cxx theora_plugin.cxx

CFLAGS +=   -I$(COMMONDIR)
LIBS   += -ltheora -logg  

INSTALL_DIR := opal-3.10.11/codecs/video
PLUGINDIR   := /home/lee/sm_for_certify/sanweixinan/crypto_voip_sm/crypto_opal/opal-3.10.11_arm/plugins
include $(PLUGINDIR)/plugin-inc.mak

###########################################
