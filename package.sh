#!/bin/sh -e
#
#  Copyright 2020, Roger Brown
#
#  This file is part of rhubarb pi.
#
#  This program is free software: you can redistribute it and/or modify it
#  under the terms of the GNU General Public License as published by the
#  Free Software Foundation, either version 3 of the License, or (at your
#  option) any later version.
# 
#  This program is distributed in the hope that it will be useful, but WITHOUT
#  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
#  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
#  more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program.  If not, see <http://www.gnu.org/licenses/>
#

# This depends on xpath from perl-XML-XPath on RPM based systems

PACKAGE_SH="$0"
CHANNEL="8.0"
RUNTIME="8.0.2"
EXTRA_ARGS="$3"
LOGNAME=`basename "$PACKAGE_SH"`

HERE=usr/share/dotnet

if test -z "$CHANNEL"
then
	CHANNEL=LTS
fi

cleanup()
{
	for d in dotnet-* aspnetcore-* netstandard-*
	do
		if test -d $d
		then
			chmod -R +w $d
			rm -rf $d
		fi
	done

	rm -rf dotnet-install.sh *.deb *.rpm
}

trap cleanup 0

if test ! -x dotnet-install.sh
then
	curl --location --fail --silent --output dotnet-install.sh https://dot.net/v1/dotnet-install.sh

	chmod +x dotnet-install.sh
fi

getarg() 
{
	LAST=
	MATCH=

	for ARG in $@
	do
		if test -z "$MATCH"
		then
			MATCH="$ARG"
		else
			if test "$LAST" = "$MATCH"
			then
				echo $ARG
			fi
			LAST="$ARG"
		fi
	done
}

first()
{
	echo $1
}

second()
{
	echo $2
}

last()
{
	LAST_V=
	for LAST_N in $@
	do
		LAST_V=$LAST_N
	done
	echo $LAST_V
}

lookup()
{
	LU_NAME="$1"
	LU_VERS="$2"
	LU_ARCH="$3"

	LU_LAST_VERS=`echo $LU_VERS | sed y/\./\ /`
	LU_LAST_VERS=`last $LU_LAST_VERS`

	(
		. /etc/os-release

		set -e

		LU_DONE=false

		for LU_ID in $ID $ID_LIKE
		do
			if test "$ID" = "$LU_ID"
			then
				BASE_ID="$VERSION_ID"
			else
				case "$LU_ID" in
					debian )
						case "$ID" in 
							raspbian )
								BASE_ID="$VERSION_ID"
								;;
							* )
								BASE_ID=11
								VERSION_CODENAME=bullseye
								;;
						esac
						;;
					centos )
						BASE_ID=8
						;;
					rhel )
						BASE_ID=8
						;;
					fedora )
						BASE_ID=36
						;;
					opensuse )
						BASE_ID=15
						;;
					* )
						BASE_ID="$VERSION_ID"
						;;
				esac
			fi

			BASE_URL="https://packages.microsoft.com/$LU_ID/$BASE_ID/prod"

			echo "$LOGNAME: lookup $BASE_URL for $LU_NAME $LU_VERS" 1>&2

			if curl --fail --location --silent --output Packages "$BASE_URL/dists/$VERSION_CODENAME/main/binary-$LU_ARCH/Packages"
			then
				PKG=
				VER=

				while read A B C
				do
					case "$A" in
					"" )
						PKG=
						VER=
						;;
					"Package:" )
						PKG="$B"
						;;
					"Version:" )
						VER="$B"
						;;
					"Filename:" )
						if test "$PKG:$VER" = "$LU_NAME:$LU_VERS-1"
						then
							echo "$BASE_URL/$B"
							LU_DONE=true
						fi
						;;
					* )
						;;
					esac
				done < Packages
			else
				if curl --silent --fail --location --output repomd.xml "$BASE_URL/repodata/repomd.xml"
				then
					if echo "<doc />" | xpath -q -e "/doc" >/dev/null 2>&1
					then
						XPATH_OPTS="-q -e"
					fi

					PRIMARY_HREF=`xpath $XPATH_OPTS 'string(/repomd/data[@type="primary"]/location/@href)' < repomd.xml 2>/dev/null`

					if curl --silent --fail --output primary.xml.gz "$BASE_URL/$PRIMARY_HREF"
					then
						gunzip primary.xml.gz

						RPM_HREF=`xpath $XPATH_OPTS "string(/metadata/package[@type=\"rpm\" and name=\"$LU_NAME\" and arch=\"x86_64\" and version[@ver=\"$LU_VERS\"]]/location/@href)" < primary.xml 2>/dev/null`

						if test -n "$RPM_HREF"
						then
							echo "$BASE_URL/$RPM_HREF"

							LU_DONE=true
						fi
					fi
				fi
			fi

			if $LU_DONE
			then
				break
			fi

			rm -rf Packages repomd.xml primary.xml primary.xml.gz
		done
	)

	rm -rf Packages repomd.xml primary.xml primary.xml.gz
}

rmdirs()
{
	find "$1" -type d | (
		RC=1
		while read N
		do
			if rmdir "$N" 2>/dev/null
			then
				RC=0
			fi
		done

		exit $RC
	)
}

package()
{
	NAME="$1"
	VERSION=

	while read A
	do
		if test -z "$VERSION"
		then
			VERSION=`getarg --version $A`
		fi
	done

	if test -n "$VERSION"
	then
		VERSION="${VERSION%\"}"
		VERSION="${VERSION#\"}"

		if test ! -f version
		then
			echo $VERSION > version
		fi
	else
		VERSION=`cat version`
	fi

	case "$NAME" in 
		dotnet-host )
			PACKAGE=$NAME
			;;
		* )
			DIGITS=`echo $VERSION | sed y/./\ /`
			VERMAJOR=`first $DIGITS`
			VERMINOR=`second $DIGITS`
			PACKAGE=$NAME-$VERMAJOR.$VERMINOR
			;;
	esac

	echo $NAME > name
	echo $PACKAGE > package

	cat version package name > /dev/null
}

write_rpm()
{
	VERSION=`cat version`
	NAME=`cat name`
	PACKAGE=`cat package`
	PWD=`pwd`
	REQUIRES=

	if test ! -d "$HERE"
	then
		echo expected root dir $HERE is not present for $NAME

		while read ORIGFILE
		do
			echo original does have $ORIGFILE

			if test "$ORIGFILE" = "/$HERE"
			then
				echo "was present in original so re-creating $HERE"
				mkdir -p "$HERE"
			fi
		done < files
	fi

	(
		if test -d usr
		then
			find usr | while read N
			do
				if test -d "$N"
				then
					case "$N" in
						$HERE/packs/Microsoft.NETCore.App.Host.linux-* )
							;;
						* )
							if grep -Fx "/$N" < files
							then
								:
							fi
							;;
					esac
				else
					echo "/$N"
				fi
			done
		else
			mkdir -p $HERE
			echo "/$HERE"
		fi
	) > files.spec

	while read N
	do
		case "$N" in 
			rpmlib* )
				;;
			* )
				if test -n "$REQUIRES"
				then
					REQUIRES="$REQUIRES, $N"
				else
					REQUIRES="$N"
				fi
				;;
		esac
	done < requires
	
	(
		(
			DESCRIPTION=false
			while read N V
			do
				case "$N" in
					"Name:" | "Version:" | "Summary:" | "License:" | "Group:" | "Release:" )
						echo "$N" "$V"
						;;
					"Description:" )
						DESCRIPTION=true
						;;
					* )
						;;
				esac

				if $DESCRIPTION
				then
					break
				fi
			done
			echo "Prefix: /usr"

			if test -n "$REQUIRES"
			then
				echo "Requires: $REQUIRES"
			fi

			echo

			if $DESCRIPTION
			then
				echo "%description"
				cat
				echo
			fi
		) < control

		if test -d usr
		then
			cat <<EOF
%files
%defattr(-,root,root)
EOF
			while read N
			do
				if test -d ".$N"
				then
					echo "%dir $N"
				else
					echo "$N"
				fi
			done < files.spec
		fi	
	) > rpm.spec

	mkdir rpms root

	if test -d usr
	then
		mv usr root/usr
	fi

	sort < files > files.sort
	sort < files.spec > root.sort

	if diff files.sort root.sort
	then
		:
	else
		MACHARCH=`uname -m`
		echo "Wrong list for NAME=$NAME, PACKAGE=$PACKAGE, VERSION=$VERSION"
		echo "Failed file list comparison ######################################################################################"
		test "$MACHARCH" != "x86_64"
	fi

	rm -rf files.sort root.sort

	rpmbuild --buildroot "$PWD/root" --define "_rpmdir $PWD/rpms" --define "_build_id_links none" -bb "$PWD/rpm.spec"

	find . -name "*.rpm" -type f | while read N
	do
		mv "$N" ..
	done

	if test -d root
	then
		chmod -R +rw root
	fi

	rm -rf rpms rpm.spec files version name requires usr package root control files.spec
}

write_deb()
{
	PACKAGE=`cat name`
	VERSION=`cat version`

	test -f control

	ARCH=`dpkg --print-architecture`

	USCORE=-
	PKGNAME="$PACKAGE$USCORE$VERSION$USCORE$ARCH.deb"

	rm -rf "$PKGNAME"

	chmod -R -w usr

	INSTALL_SIZE=
	ACTUAL_SIZE=

	while read A B C
	do
		case "$A" in
			Installed-Size: )
				INSTALL_SIZE="$B"
				;;
			* )
				;;
		esac
	done < control
	
	if test -n "$INSTALL_SIZE"
	then
		OUTPUT=`du -sk usr`
		
		while read A B C
		do
			ACTUAL_SIZE="$A"
		done <<EOF
$OUTPUT
EOF

		if test -n "$ACTUAL_SIZE"
		then
			sed "s/Installed-Size: $INSTALL_SIZE/Installed-Size: $ACTUAL_SIZE/" <control >control.size
			mv control.size control
		fi

	fi

	tar --owner=0 --group=0 --create --xz --file control.tar.xz ./control
	tar --owner=0 --group=0 --create --xz --file data.tar.xz ./usr

	if test -d usr
	then
		chmod -R +rw usr
		rm -rf usr
	fi

	echo "2.0" >debian-binary

	ar r "$PKGNAME" debian-binary control.tar.xz data.tar.xz

	rm control data.tar.xz control.tar.xz debian-binary version name package

	mv "$PKGNAME" ..
}

tarxvf()
{
	if tar $@ 2>/dev/null
	then
		true
	fi
}

writeControl()
{
	ARCH=`dpkg --print-architecture`

	sed "s/Architecture: amd64/Architecture: $ARCH/"
}

get_package()
{
	VERSION=`cat version`
	NAME=`cat name`
	PACKAGE=`cat package`

	if test ! -d usr
	then
		mkdir tmp

		TMPDIR=tmp ../dotnet-install.sh --install-dir "$HERE" $@ --version $VERSION $EXTRA_ARGS

		RC=$?

		rm -rf tmp

		if test "$RC" -gt 0
		then
			exit 1
		fi	

		find "$HERE" -name dotnet -type f

		find "$HERE" -name dotnet -type f | (
			set -e
			while read N
			do
				if test -x "$N"
				then
					"$N" --list-runtimes
				fi
			done
		)

		if test $? -gt 0
		then
			echo error detected with download
			exit 1
		fi	
	fi

	MASTER_URL=`lookup $PACKAGE $VERSION amd64`

	if test -z "$MASTER_URL"
	then
		echo "$LOGNAME: url for $PACKAGE $VERSION not found"
	else
		MASTER_PKG=`basename "$MASTER_URL"`

		if test ! -f "$MASTER_PKG"
		then
			echo "$LOGNAME: curl $MASTER_URL"
			curl --fail --location --silent --output "$MASTER_PKG" "$MASTER_URL"
		fi

		ORIGINALS_WANTED="usr/share/doc/$PACKAGE usr/share/man usr/bin"
		WANTED_POSTER=

		for d in $ORIGINALS_WANTED
		do
			WANTED_POSTER="$WANTED_POSTER $d ./$d"
		done

		CONTROL_FILES="./control control"

		case "$MASTER_PKG" in
			*.deb )
				ar t "$MASTER_PKG" | while read N
				do
					case "$N" in 
						data.tar.gz )
							ar p "$MASTER_PKG" "$N" | tarxvf --gzip -x -f - $WANTED_POSTER
							;;
						data.tar.xz )
							ar p "$MASTER_PKG" "$N" | tarxvf --xz -x -f - $WANTED_POSTER
							;;
						control.tar.gz )
							ar p "$MASTER_PKG" "$N" | tarxvf --gzip -x -f - $CONTROL_FILES
							writeControl < control > control.new
							mv control.new control
							;;
						control.tar.xz )
							ar p "$MASTER_PKG" "$N" | tarxvf --xz -x -f - $CONTROL_FILES
							writeControl < control > control.new
							mv control.new control
							;;
						* )
							;;
					esac
				done
				;;
			*.rpm )
				rpm -qip "$MASTER_PKG" | (
					while read LINE_IN
					do
						LINE_OUT=
						COLON_FOUND=false

						for LINE_D in $LINE_IN
						do
							if $COLON_FOUND
							then
								LINE_OUT="$LINE_OUT $LINE_D"
							else
								LINE_OUT="$LINE_OUT$LINE_D"
							fi

							case "$LINE_D" in
								*: )
									COLON_FOUND=true
									;;
								* )
									;;
							esac
						done

						echo $LINE_OUT 

						if test "$LINE_OUT" = "Description:"
						then
							break
						fi
					done

					cat
				) > control
				rpm -qpR "$MASTER_PKG" > requires
				rpm -qlp "$MASTER_PKG" > files
				rpm2cpio "$MASTER_PKG" | (
					set -e
					mkdir cpio.data
					cd cpio.data
					cpio -idm
				
					for d in $ORIGINALS_WANTED
					do
						if test -d "$d"
						then
							(
								tar cf - "$d"
							) | (
								cd ..
								tar xf -
							)
						fi
					done
				)
				rm -rf cpio.data
				;;
			* )
				;;
		esac

		rm "$MASTER_PKG"
	fi
}

split_package()
{
	THISPKG="$1"

	while read PACKS PACKNAME PACKROOT 
	do
		if test -d "$HERE/$PACKS/$PACKNAME"
		then
			if test "$THISPKG" != "$PACKROOT"
			then
				if test -d "../$PACKROOT/$HERE/$PACKS/$PACKNAME"
				then
					rm -rf "$HERE/$PACKS/$PACKNAME"
				else
					mkdir -p "../$PACKROOT/$HERE/$PACKS"

					( 
						cd "$HERE/$PACKS/$PACKNAME"
						ls
					) > "../$PACKROOT/version"
	
					mv "$HERE/$PACKS/$PACKNAME" "../$PACKROOT/$HERE/$PACKS/$PACKNAME"
				fi
			fi
		fi
	done <<EOF
packs NETStandard.Library.Ref netstandard-targeting-pack
packs Microsoft.NETCore.App.Ref dotnet-targeting-pack
packs Microsoft.AspNetCore.App.Ref aspnetcore-targeting-pack
shared Microsoft.AspNetCore.App aspnetcore-runtime
shared Microsoft.AspNetCore.All aspnetcore-runtime
shared Microsoft.NETCore.App dotnet-runtime
host fxr dotnet-hostfxr
EOF

	if test "$THISPKG" != "dotnet-host"
	then
		(
			cd $HERE
			ls
		) | while read N
		do
			if test -f "$HERE/$N"
			then
				if test -f "../dotnet-host/$HERE/$N"
				then
					rm "$HERE/$N"
				else
					mkdir -p "../dotnet-host/$HERE"
					mv "$HERE/$N" "../dotnet-host/$HERE/$N"
				fi
			fi
		done
	fi
}

if test ! -d dotnet-host
then
	if (
		set -e

		mkdir dotnet-host

		cd dotnet-host

		if test -z "$RUNTIME"
		then
			../dotnet-install.sh --dry-run --channel $CHANNEL --install-dir "$HERE" --runtime dotnet $EXTRA_ARGS
		else
			echo "--version $RUNTIME"
		fi | package dotnet-host 

		get_package --runtime dotnet

		split_package dotnet-host
	)
	then
		true
	else
		rm -rf dotnet-host
	fi
fi

if test ! -d aspnetcore-runtime
then
	if (
		set -e

		mkdir aspnetcore-runtime

		cd aspnetcore-runtime

		if test -z "$RUNTIME"
		then
			../dotnet-install.sh --dry-run --channel $CHANNEL --install-dir "$HERE" --runtime aspnetcore $EXTRA_ARGS
		else
			echo "--version $RUNTIME"
		fi | package aspnetcore-runtime 

		get_package --runtime aspnetcore

		split_package aspnetcore-runtime
	)
	then
		true
	else
		rm -rf aspnetcore-runtime
	fi
fi

if test ! -d dotnet-sdk
then
	if (
		set -e

		mkdir dotnet-sdk

		cd dotnet-sdk

		../dotnet-install.sh --dry-run --channel $CHANNEL --install-dir "$HERE" $EXTRA_ARGS --version 8.0.200 | package dotnet-sdk
		
		get_package 

		split_package dotnet-sdk

		for d in $HERE/packs/Microsoft.NETCore.App.Host.*
		do
			if test -d "$d"
			then
				mkdir -p "../dotnet-apphost-pack/$HERE/packs"

				( 
					cd "$d"
					ls
				) > "../dotnet-apphost-pack/version"

				mv "$d" "../dotnet-apphost-pack/$HERE/packs"
			fi
		done
	)
	then
		true
	else
		rm -rf dotnet-sdk
	fi
fi

if test ! -f dotnet-host/version
then
	cp dotnet-hostfxr/version dotnet-host/version
fi

if test -f dotnet-runtime/version
then
	if test ! -f dotnet-runtime-deps/version
	then
		mkdir -p dotnet-runtime-deps/usr
		cp dotnet-runtime/version dotnet-runtime-deps/version
	fi
fi

for d in dotnet-host dotnet-hostfxr dotnet-runtime-deps dotnet-runtime netstandard-targeting-pack dotnet-targeting-pack dotnet-apphost-pack aspnetcore-targeting-pack aspnetcore-runtime
do
	if test -d $d
	then
	(
		set -e

		cd $d

		package $d < /dev/null

		get_package
	)
	fi
done

PACK_VERS=`cat dotnet-runtime/version`

for PKG in dotnet-* aspnetcore-* netstandard-*
do
	if test -d "$PKG"
	then
		while rmdirs "$PKG"
		do
			true
		done

		(
			set -e

			cd "$PKG"

			if test -f files
			then
				write_rpm
			else
				write_deb
			fi
		)

		ls "$PKG"

		rmdir "$PKG"
	fi
done


HAVE_DEB=false
HAVE_RPM=false

for d in *.deb
do
	if test -f "$d"
	then
		HAVE_DEB=true
		break
	fi
done

for d in *.rpm
do
	if test -f "$d"
	then
		HAVE_RPM=true
		break
	fi
done

if $HAVE_DEB
then
	ARCH=`dpkg --print-architecture`
	TARNAME=dotnet-"$PACK_VERS"-"$ARCH".deb.tar
	echo "$LOGNAME: $TARNAME"
	tar --owner=0 --group=0 --create --file "$TARNAME" *.deb
fi

if $HAVE_RPM
then
	ARCH=`uname -m`
	TARNAME=dotnet-"$PACK_VERS"-"$ARCH".rpm.tar
	echo "$LOGNAME: $TARNAME"
	tar --owner=0 --group=0 --create --file "$TARNAME" *.rpm
fi
