#!/bin/bash
#
# $Id$
#
#-----------------------------------------------
# Function to verfy rpm installation 
# based on input rpm list provided by update.sh
# (also has a remove mode to make sure that a
# particular package is removed).
#
# Texas Advanced Computing Center 
#-----------------------------------------------

VERBOSE=0
DEFAULT_ARCH=x86_64

function verify_rpms
{
    
  local RPM_LIST=$1 
  local REMOVE_FLAG=$2
    
  if [ "$REMOVE_FLAG" != "REMOVE" ];then
	
      for i in $RPM_LIST; do
	  let "count = count + 1"
	  num_versions=1
	  NO_UPGRADE=0
	  
	  igot=`echo $i | grep ','`
	  if [ "x$igot" != "x" ];then
	      num_versions=`echo $i | tr -cd [,] | wc -c`
	      let "num_versions=$num_versions+1"
	      echo "Multi-version package found...($num_versions:$i)" 
	      NO_UPGRADE=1
	  fi

	  # Multiple version out of date check: for packages with
	  # multiple versions, check all requested revisions first to
	  # see if any are out of date; if so, they will need to be
	  # removed (since we cannot do upgrades for packages with
	  # multiple versions).

	  if [ $num_versions -gt 1 ];then
	      ERASE_PREVIOUS=0
	      for j in `seq 1 $num_versions`; do 

		  myrpm=`echo $i | awk -F ',' '{print $'"$j}"`

		  export PACKAGE=`echo $myrpm | awk -F : '{print $1}'`
		  export VERSION=`echo $myrpm | awk -F : '{print $2}'`
		  
                 # New method to deal with things like "charm++"
	      
		  my_ver=`rpm -qi $PACKAGE-$VERSION | grep "\bVersion     " | awk '{print $3}'`
		  my_rel=`rpm -qi $PACKAGE-$VERSION | grep "\bRelease     " | awk '{print $3}'`
		  
		  INSTALLED="$my_ver-$my_rel"
		  
		  if [ "$VERSION" != "$INSTALLED" ];then
		      ERASE_PREVIOUS=1
		  fi
	      done
	      
	      if [ $ERASE_PREVIOUS -eq 1 ];then
		  if [ $UPDATE_RPMS == 1 ];then
		      rpm -ev --allmatches --ignoresize $PACKAGE
		  fi
	      fi
	  fi


	  for j in `seq 1 $num_versions`; do 
	      if [ $num_versions -gt 1 ];then
		  myrpm=`echo $i | awk -F ',' '{print $'"$j}"`
		  echo "Analyzing $myrpm"
		  export PACKAGE=`echo $myrpm | awk -F : '{print $1}'`
		  export VERSION=`echo $myrpm | awk -F : '{print $2}'`
	      else
		  export PACKAGE=`echo $i | awk -F : '{print $1}'`
		  export VERSION=`echo $i | awk -F : '{print $2}'`

		  #--------------------------------------------------
		  # Check for specification of a target architecture;
		  # if not, assume the default arch
		  #--------------------------------------------------

		  myarch=$DEFAULT_ARCH
		  
		  match=`echo $VERSION | egrep ".x86_64\b"`
		  if [ "x$match" != "x" ]; then
		      myarch="x86_64"
		      VERSION=`echo $VERSION | awk -F ".$myarch" '{print $1}'`
		  fi

		  match=`echo $VERSION | egrep ".i386\b"`
		  if [ "x$match" != "x" ]; then
		      myarch="i386"
		      VERSION=`echo $VERSION | awk -F ".$myarch" '{print $1}'`
		  fi

		  match=`echo $VERSION | egrep ".i686\b"`
		  if [ "x$match" != "x" ]; then
		      myarch="i686"
		      VERSION=`echo $VERSION | awk -F ".$myarch" '{print $1}'`
		  fi

#		  echo "myarch = $myarch"

	      fi
	      
              # New method to deal with things like "charm++"

###	      echo "rpm -qi $PACKAGE-$VERSION.$myarch"
	      
#	      my_ver=`rpm -qi $PACKAGE-$VERSION | grep "\bVersion     " | awk '{print $3}'`
	      my_ver=`rpm -qi $PACKAGE-$VERSION.$myarch | grep "\bVersion     " | awk '{print $3}'`
	      my_rel=`rpm -qi $PACKAGE-$VERSION.$myarch | grep "\bRelease     " | awk '{print $3}'`
	      
	      INSTALLED="$my_ver-$my_rel"

	      export NOT_INSTALLED=`echo $INSTALLED | awk '{print $3}'`
	      
	      if [ "$VERBOSE" == 1 ];then
		  echo "desired version   = $VERSION"
		  echo "installed version = $INSTALLED"
	      fi
	      
	      if [ "$VERSION" != "$INSTALLED" ];then
		  echo "checking on $PACKAGE"
		  export NEEDS_UPDATE=1
		  
		  if [ "$VERBOSE" == 1 ]; then
		      printf "%-25s %8s" $PACKAGE $INSTALLED
		      printf "%8s\n" "No"
		  else
		      if [ "$NOT_INSTALLED" == "not" ]; then
			  echo "$PACKAGE is *not* Installed, Desired = $VERSION"
		      else
			  echo "$PACKAGE is out of date: Installed = $INSTALLED, Desired = $VERSION"
		      fi
		  fi
		  
                  # Install the desired package.
		  
		  if [ $UPDATE_RPMS == 1 ];then

		      if [ $NO_UPGRADE -eq 1 ];then
			  rpm_opt="-ivh"
		      else
			  rpm_opt="-Uvh"
		      fi

#		      echo "rpm_opt = $rpm_opt"
		      
		      if [ -s $SRC_DIR/$MYARCH/$PACKAGE-$VERSION.$MYARCH.rpm ]; then
			  rpm --ignoresize $rpm_opt --nodeps $SRC_DIR/$MYARCH/$PACKAGE-$VERSION.$MYARCH.rpm
		      elif [ -s $SRC_DIR/noarch/$PACKAGE-$VERSION.noarch.rpm ]; then
			  rpm --ignoresize $rpm_opt --nodeps $SRC_DIR/noarch/$PACKAGE-$VERSION.noarch.rpm
		      elif [ "$MODE" == "ROCKS" ];then
			  rpm --ignoresize $rpm_opt --nodeps $SRC_DIR/$MYARCH/$PACKAGE-$VERSION.$MYARCH.rpm
		      else
			  echo "$SRC_DIR/$MYARCH"
			  echo "Error: Unable to find rpm for $PACKAGE"
			  exit 1
		      fi
		      
		         # Special Post-processing for kernel installs.
		      
		      if [ "$PACKAGE" = "kernel" ]; then
			  echo "Updating kernel initrd image."
			  export KERNEL_VER=`echo $VERSION | awk -F "-" '{print $1}'`
			  echo "Image name = $KERNEL_VER.img"
			  /sbin/mkinitrd -f /boot/initrd-$KERNEL_VER.img --preload=mptsas --preload=mptscsih $KERNEL_VER
		      fi
		  fi
	      else
		  if [ "$VERBOSE" == 1 ]; then
		      printf "%-25s %8s" $PACKAGE $INSTALLED
		      printf "%8s\n" "X"
		  fi
	      fi
	  done
      done
	
  else

      # Verify non-existence of RPMs

      for i in $RPM_LIST; do

	  let "count = count + 1"
	
	  export PACKAGE=`echo $i | awk -F : '{print $1}'`
	  export VERSION=`echo $i | awk -F : '{print $2}'`
###	    export INSTALLED=`rpm -q $PACKAGE-$VERSION | awk -F "$PACKAGE-" '{print $2}'`
	  export INSTALLED=`rpm -q $PACKAGE-$VERSION | sed -e "s/$PACKAGE\-\(.*\)/\1/g"`
	  
	  if [ "$VERSION" == "$INSTALLED" ];then
	      echo "$PACKAGE is *installed* and will be removed"
	      export NEEDS_UPDATE=1
	      
            # Uninstall the desired package.
	      
	      if [ $UPDATE_RPMS == 1 ];then
		  rpm -e --nodeps --ignoresize $PACKAGE-$VERSION
	      fi
	  fi
	  
      done
      
  fi
  
}
