#!/bin/bash

helpFunction()
{
   echo ""
   echo "Usage: $0 -n number"
   echo -e "\t-n number"
   exit 1
}

while getopts "n:" opt
do
    case "$opt" in
        n ) number="$OPTARG" ;;
        ? ) helpFunction ;;
    esac
done

if  [ -z "$number" ]
then
  echo "Some or all of the parameters are empty";
  helpFunction
fi

rm -f input_*.txt
for (( c=1; c<=$number; c++ ))
do  
  cp input.txt input_$c.txt
done