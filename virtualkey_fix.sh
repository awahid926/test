#!/bin/sh

FILE=`find . -name "*.c"`

echo $FILE

for i in $FILE; do
	echo $i
	NAME=`sed -n '/find_virtualkey/ p' $i`
	NAME=${NAME#*find_virtualkey(}
	NAME=${NAME%%)*}
	sed -i 's/find_virtualkey(.*code/find_virtualkeys('$NAME', event->key.sym/' $i
done

