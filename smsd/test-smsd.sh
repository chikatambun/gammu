#!@SH_BIN@

set -x
set -e
SMSD_PID=0

cleanup() {
    if [ $SMSD_PID -ne 0 ] ; then
        kill $SMSD_PID
        sleep 1
    fi
}

trap cleanup INT QUIT EXIT

rm -rf smsd-test
mkdir smsd-test
cd smsd-test
# Create database
@SQLITE_BIN@ smsd.db < @CMAKE_CURRENT_SOURCE_DIR@/../docs/sql/sqlite.sql
# Dummy backend storage
mkdir gammu-dummy
# Create config file
cat > .smsdrc <<EOT
[gammu]
model = dummy
connection = none
port = @CMAKE_CURRENT_BINARY_DIR@/smsd-test/gammu-dummy
gammuloc = /dev/null
loglevel = textall

[smsd]
service = dbi
driver = sqlite3
database = smsd.db
commtimeout = 1
dbdir = @CMAKE_CURRENT_BINARY_DIR@/smsd-test/
debuglevel = 255
logfile = stderr
runonreceive = @CMAKE_CURRENT_BINARY_DIR@/smsd-test/received.sh
EOT

cat > @CMAKE_CURRENT_BINARY_DIR@/smsd-test/received.sh << EOT
#!@SH_BIN@
echo "\$@" >> @CMAKE_CURRENT_BINARY_DIR@/smsd-test/received.log
EOT
chmod +x @CMAKE_CURRENT_BINARY_DIR@/smsd-test/received.sh

CONFIG_PATH="@CMAKE_CURRENT_BINARY_DIR@/smsd-test/.smsdrc"
DUMMY_PATH="@CMAKE_CURRENT_BINARY_DIR@/smsd-test/gammu-dummy"

mkdir -p $sms $DUMMY_PATH/sms/1
mkdir -p $sms $DUMMY_PATH/sms/2
mkdir -p $sms $DUMMY_PATH/sms/3
mkdir -p $sms $DUMMY_PATH/sms/4
mkdir -p $sms $DUMMY_PATH/sms/5

@CMAKE_CURRENT_BINARY_DIR@/gammu-smsd -c "$CONFIG_PATH" &
SMSD_PID=$!

sleep 3

for sms in @CMAKE_CURRENT_SOURCE_DIR@/../tests/at-sms-encode/0[1-9].backup ; do
    number=`echo $sms | @SED_BIN@ 's@.*/0*\([1-9][0-9]*\).backup@\1@'`
    cp $sms $DUMMY_PATH/sms/1/$number
done

sleep 5

@CMAKE_CURRENT_BINARY_DIR@/gammu-smsd-inject -c "$CONFIG_PATH" TEXT 123465 -text "Lorem ipsum."

for sms in @CMAKE_CURRENT_SOURCE_DIR@/../tests/at-sms-encode/0[1-9].backup ; do
    number=`echo $sms | @SED_BIN@ 's@.*/0*\([1-9][0-9]*\).backup@\1@'`
    cp $sms $DUMMY_PATH/sms/3/$number
done

sleep 10
@CMAKE_CURRENT_BINARY_DIR@/gammu-smsd-monitor -C -c "$CONFIG_PATH" -l 1 -d 0

if [ `wc -l < @CMAKE_CURRENT_BINARY_DIR@/smsd-test/received.log` -ne 18 ] ; then
    echo "Wrong number of messages received!"
    exit 1
fi