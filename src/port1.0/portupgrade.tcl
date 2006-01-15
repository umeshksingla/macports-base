# et:ts=4
# portupgrade.tcl
# $Id: portupgrade.tcl,v 1.1.2.5 2006/01/15 19:25:51 olegb Exp $
#
# Copyright (c) 2006 Ole Guldberg Jensen <olegb@opendarwin.org>
# Copyright (c) 2002 - 2003 Apple Computer, Inc.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
# 3. Neither the name of Apple Computer, Inc. nor the names of its contributors
#    may be used to endorse or promote products derived from this software
#    without specific prior written permission.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
#

package provide portupgrade 1.0
package require portutil 1.0
package require registry 1.0

set com.apple.upgrade [target_new com.apple.upgrade upgrade_main]
target_state ${com.apple.upgrade} no
target_provides ${com.apple.upgrade} upgrade
target_requires ${com.apple.upgrade} main

proc upgrade_main {args} {

	global portname portversion portpath categories description long_description homepage depends_run installPlist package-install uninstall workdir worksrcdir pregrefix UI_PREFIX destroot portrevision maintainers ports_force portvariants targets depends_lib PortInfo epoch prefix pkg_server ports_binary_only

	# Map portname to suit RPM-ification
	set portname [string map {- _} $portname]

	# Get oldversion
	set oldvlist [registry::installed $portname $portversion]
	# XXX Hack, we should check if we have more that one installed XXX
	set oldvlist [lindex $oldvlist 0]
	set oldversion {}
	if { [lindex $oldvlist 2] eq {} } {
		set oldversion "[lindex $oldvlist 0]-[lindex $oldvlist 1]-0"
	} else {
		set oldversion "[lindex $oldvlist 0]-[lindex $oldvlist 1]-[lindex $oldvlist 2]"
	}

	# Get newversion
	set newversion $portname-$portversion-$portrevision 

	# Compare versions
	ui_msg "Comparing $oldversion and $newversion"
	if {![rpm-vercomp $newversion $oldversion] > 0 } {
		ui_debug "Upgrade not needed"
		return 0
	} else {
		ui_debug "Upgrading $portname"
	}
	set arch [option os.arch]
	if {$arch eq "powerpc"} {
		set arch "ppc"
	}

	set distfile ${portname}-${portversion}-${portrevision}.${arch}.rpm
	set site ${pkg_server}

	# Check if we have the package 
	set havepackage no
	if { [file exist [file join ${prefix}/src/apple/RPMS/${arch} ${distfile}]] } {
		ui_debug "Package allready present - Not fetching .."
		set havepackage yes
	}

	# If we want binary packages
	if { [info exists ports_binary_only] && $ports_binary_only == "yes" && $havepackage == "no" } {
		# Fetch the file $portname-$portversion-$portrevision.$arch.rpm from $pkg_server 
		ui_msg "$UI_PREFIX [format [msgcat::mc "Attempting to fetch %s from %s"] $distfile $site]"

		set file_url [portfetch::assemble_url $site $distfile]
		if {![catch {eval curl fetch {$file_url} ${prefix}/src/apple/RPMS/${arch}/${distfile}.TMP} result] && ![catch {system "mv ${prefix}/src/apple/RPMS/${arch}/${distfile}.TMP ${prefix}/src/apple/RPMS/${arch}/${distfile}"}]} {
			set havepackage yes
		} else {
			ui_debug "[msgcat::mc "Fetching failed:"]: $result"
			exec rm -f ${prefix}/share/apple/RPMS/${arch}/{distfile}.TMP
		}
	}

	if { $havepackage neq "yes" } {
		# Build own package
		ui_debug "Building local package ..."
	}

	ui_msg "$UI_PREFIX [format [msgcat::mc "Upgrading package: %s"] ${portname}]"

	system "rpm -Uvh --nodeps ${prefix}/src/apple/RPMS/${arch}/${portname}-${portversion}-${portrevision}.${arch}.rpm"

    return 0
}
