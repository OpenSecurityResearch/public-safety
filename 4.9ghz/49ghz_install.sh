RUN_DIR=`pwd`

COMPAT_VER=compat-wireless-3.3-1
CRDA_VER=crda-1.1.2
REGDB_VER=wireless-regdb-2011.04.28

DB_VER=db-ReturnTrue.txt
KIS_VER=kismet-ReturnTrue.txt
PATCH_NAME=compat-wireless-3.3-1_ath5k-49GHZ+BWMODE.patch

mount -o remount,rw /cdrom

echo "[+] Changing directories to $RUN_DIR"
cd $RUN_DIR

if [ ! -f $PATCH_NAME ]; then
	echo "[!] Can't find $PATCH_NAME! ..Attempting to download"
	https://raw.github.com/OpenSecurityResearch/public-safety/master/4.9ghz/$PATCH_NAME
fi
if [ ! -f $PATCH_NAME ]; then
	echo "[!] Something's wrong - can't find $PATCH_NAME"
	echo "[!] Do you have internet access?"
	echo "[!] Exiting....."
	exit
fi

rm -rf $COMPAT_VER $CRDA_VER $REGDB_VER

echo "[+] Installing pre-requisites"
if [ -d /cdrom/package ]; then
	sudo dpkg --install /cdrom/package/libnl-dev_1.1-5build1_i386.deb 
	sudo dpkg --install /cdrom/package/libssl-dev_0.9.8k-7ubuntu8.8_i386.deb
else
	echo "[!] Could not find /cdrom/package! Looking for $RUN_DIR/packages/"
fi

if [ -d $RUN_DIR/packages ]; then
	sudo apt-get -o=dir::cache=$RUN_DIR/packages/ -f install
	sudo apt-get -o=dir::cache=$RUN_DIR/packages/ install python-m2crypto libssl-dev build-essential
else
	echo "[!] Could not find $RUN_DIR/packages/.. installing from internet"
	sudo apt-get update
	sudo apt-get -y -f install
	sudo apt-get -y install python-m2crypto libssl-dev build-essential libnl-dev
fi

cd $RUN_DIR

echo "[+] Creating Public/Private Keys"
openssl genrsa -out key_for_regdb.priv.pem 2048
openssl rsa -in key_for_regdb.priv.pem -out key_for_regdb.pub.pem -pubout -outform PEM

echo "[+] Extracting/Installing regdb"
cd $RUN_DIR

if [ ! -f $REGDB_VER.tar.bz2 ]; then 
	echo "[!] Could not find $REGDB_VER.tar.bz2 - attempting to download"
	wget http://linuxwireless.org/download/wireless-regdb/$REGDB_VER.tar.bz2
fi

tar -jxf $REGDB_VER.tar.bz2
cd $RUN_DIR/$REGDB_VER
mv db.txt db.orig

if [ ! -f $DB_VER ]; then
        echo "[!] Can't find $DB_VER! ..Attempting to download"
	cd $RUN_DIR
        https://raw.github.com/OpenSecurityResearch/public-safety/master/4.9ghz/$DB_VER
	cd $RUN_DIR/$REGDB_VER
fi


cp $RUN_DIR/$DB_VER db.txt 

make
./db2bin.py regulatory.bin db.txt $RUN_DIR/key_for_regdb.priv.pem 
sudo make install
sudo cp $RUN_DIR/key_for_regdb.pub.pem /usr/lib/crda/pubkeys/


echo "[+] Extracting/Installing CRDA"
cd $RUN_DIR
if [ ! -f $CRDA_VER.tar.bz2 ]; then
        echo "[!] Could not find $CRDA_VER.tar.bz2 - attempting to download"
	wget http://linuxwireless.org/download/crda/crda-1.1.2.tar.bz2
fi

tar -jxf $CRDA_VER.tar.bz2
cd $RUN_DIR/$CRDA_VER
cp $RUN_DIR/key_for_regdb.pub.pem pubkeys/
make
sudo make install

echo "[+] Setting up modules"
sudo ln -s /usr/src/linux /lib/modules/`uname -r`/build

echo "[+] Extracting compat-wireless"
cd $RUN_DIR
if [ ! -f $COMPAT_VER.tar.bz2 ]; then
        echo "[!] Could not find $COMPAT_VER.tar.bz2 - attempting to download"
	wget http://www.orbit-lab.org/kernel/compat-wireless-3-stable/v3.3/compat-wireless-3.3-1.tar.bz2
fi
tar -jxf $COMPAT_VER.tar.bz2  

echo "[+] Unloading old drivers"
cd $RUN_DIR/$COMPAT_VER
sudo scripts/wlunload.sh
sudo modprobe -r b43 ath5k ath iwlwifi iwlagn mac80211 cfg80211

echo "[+] Using driver-select for ath5k"
scripts/driver-select ath5k

echo "[+] Patching compat-wireless with aircrack-ng patches"

AIRCRACK_PATCHES="mac80211-2.6.29-fix-tx-ctl-no-ack-retry-count.patch mac80211.compat08082009.wl_frag+ack_v1.patch zd1211rw-2.6.28.patch ipw2200-inject.2.6.36.patch"

for i in $AIRCRACK_PATCHES
do 
	cd $RUN_DIR
	if [ ! -d $RUN_DIR/patches ]; then
		echo "[!] Could not find $RUN_DIR/patches"
		echo "[!] Downloading 2.6.39.patches.tar"
		wget http://www.backtrack-linux.org/2.6.39.patches.tar
		tar -xf 2.6.39.patches.tar
	fi
	if [ ! -f $RUN_DIR/patches/$i ]; then
		echo "[!] Something is funky - Could not find $i"
		echo "[!] Attempting to download from aircrack-ng.org...."
		if [ ! -d $RUN_DIR/patches ]; then
			mkdir $RUN_DIR/patches
		fi
		cd $RUN_DIR/patches/
		wget http://patches.aircrack-ng.org/$i
	fi
	cd $RUN_DIR/$COMPAT_VER
	echo "[+] Applying $i"
	patch -p1 < $RUN_DIR/patches/$i
done

cd $RUN_DIR/$COMPAT_VER

echo "[+] Applying shady brad patch"
patch -p1 < $RUN_DIR/$PATCH_NAME


echo "[+] Building $COMPAT_VER"
make
sudo make install
sudo make wlunload

#um /lib/modules/2.6.39.4/kernel/drivers/net/wireless/ath/ath5k/ath5k.ko
#942e1f025d5065174dc2aac6a4d39155  /lib/modules/2.6.39.4/kernel/drivers/net/wireless/ath/ath5k/ath5k.ko

cd $RUN_DIR
if [ -f $RUN_DIR/packages/kismet_svn-3505-1_i386.deb ]; then 
	echo "[+] Installing Kismet SVN 3505"
	echo "[+] Uninstalling BT5R2's kismet"
	dpkg -r kismet

	dpkg --install $RUN_DIR/packages/kismet_svn-3505-1_i386.deb
else 
	echo "[+] Could not find pre-compiled kismet.."
	echo "[+] Attempting to fetch kismet via git"
	cd $RUN_DIR
	git clone https://www.kismetwireless.net/kismet.git
	if [ -d $RUN_DIR/kismet ]; then 
		echo "[+] Uninstalling BT5R2's kismet"
		dpkg -r kismet

		cd kismet
		./configure
		make dep
		make 
		make install

		if [ ! -f $KIS_VER ]; then
		        echo "[!] Can't find $KIS_VER! ..Attempting to download"
			cd $RUN_DIR
		        https://raw.github.com/OpenSecurityResearch/public-safety/master/4.9ghz/$KIS_VER
		fi


		echo "[+] Copying over kismet.conf"
		sudo cp $RUN_DIR/$KIS_VER /usr/local/etc/kismet.conf

	else
		echo "[!] Looking like something went wrong when downloading kismet"
		echo "[!] The driver should be installed, its highly recommended that you use the latest kismet version"
	fi
fi

cd $RUN_DIR

echo "-------------------------------------"
echo "[+] Ok! All done!"
echo "[+] Load with:"
echo -e "\tmodprobe ath5k default_bwmode=1\n"
echo -e "\tdefault_bwmode can be:\n"
echo -e "\t0=20MHz; 1=5MHz; 2=10MHz; 3=40MHz\n"

echo "[+] Autocreating mon0 interface with 10mhz channels with:"
echo -e "[+] \tsudo modprobe ath5k default_bwmode=2"
echo -e "[+] \tsleep"
echo -e "[+] \tsudo iw dev wlan1 interface add mon0 type monitor"
echo -e "[+] \tsudo ifconfig mon0 up"
echo -e "[+] \tsudo iwconfig mon0 freq 4.920G (Not really needed)"

sudo modprobe ath5k default_bwmode=2
sleep 5
sudo iw dev wlan1 interface add mon0 type monitor
sudo ifconfig mon0 up
sudo iwconfig mon0 freq 4.920G
