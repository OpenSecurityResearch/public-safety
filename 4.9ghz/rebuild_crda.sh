RUN_DIR=`pwd`
CRDA_VER=crda-1.1.2
REGDB_VER=wireless-regdb-2011.04.28
DB_VER=db-ReturnTrue.txt

if [ -d $REGDB_VER ]; then 
	if [ -d $CRDA_VER ]; then
		cd $REGDB_VER 
		cp ../db-ReturnTrue.txt db.txt
		make
		./db2bin.py regulatory.bin db.txt ../key_for_regdb.priv.pem
		make install
		cd ../$CRDA_VER
		make 
		make install
	else 
		echo "Sorry bro - cant find crda.."
	fi
else 
	echo "Can't find wireless-regdb, building from scratch"
	echo "[+] Creating Public/Private Keys"
	openssl genrsa -out key_for_regdb.priv.pem 2048
	openssl rsa -in key_for_regdb.priv.pem -out key_for_regdb.pub.pem -pubout -outform PEM
	echo "[+] Extracting/Installing regdb"
	cd $RUN_DIR
	tar -jxf $REGDB_VER.tar.bz2
	cd $RUN_DIR/$REGDB_VER
	mv db.txt db.orig
	cp $RUN_DIR/$DB_VER db.txt

	make
	./db2bin.py regulatory.bin db.txt $RUN_DIR/key_for_regdb.priv.pem
	make install
	cp $RUN_DIR/key_for_regdb.pub.pem /usr/lib/crda/pubkeys/


	echo "[+] Extracting/Installing CRDA"
	cd $RUN_DIR
	tar -jxf $CRDA_VER.tar.bz2
	cd $RUN_DIR/$CRDA_VER
	cp $RUN_DIR/key_for_regdb.pub.pem pubkeys/
	make
	make install

fi
