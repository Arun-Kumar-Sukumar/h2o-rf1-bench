#!/bin/bash
OUT=h2o-covtype-analysis-20121226-172210.txt
cnt=1
rm -rf tree.txt
grep "Tree :" $OUT | while read tree; do
    echo "$tree" | sed -e "s/A/\nA/g" | grep "<" | sed "s/\([^ ]*\) .*/\1/" | sort | uniq -c | sort -nr | head -n 20 | sed -e "s/^ *//" > tmp.txt
    cnt=`expr $cnt + 1`
    if [ -f "tree.txt" ]; then 
        paste --delimiters=, tree.txt tmp.txt > tmp2.txt
    else
        mv tmp.txt tmp2.txt
    fi
    mv tmp2.txt tree.txt
    rm -rf tmp.txt tmp2.txt
done
