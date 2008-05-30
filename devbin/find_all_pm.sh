there=`dirname $0`
here=`(cd $there/..; pwd)`

find $here -name \*pm | egrep -v '(tsts/unittest-data|/lib/perl|/lib/old|/data/old)' >allperl.txt
find $here/lib -name \*pm | grep lib/Idval >libperl.txt

