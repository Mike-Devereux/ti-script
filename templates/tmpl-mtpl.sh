#!/bin/bash
#
#$ -cwd
#$ -S /bin/bash
#$ -pe smp 8
#$ -N NNN


export LD_LIBRARY_PATH=/opt/intel/l_fcompxe_2013.4.183_redist/compiler/lib/intel64/:/opt/intel/openmpi/lib64/:$LD_LIBRARY_PATH
export PATH=/opt/intel/l_fcompxe_2013.4.183_redist/compiler/lib/intel64/:/opt/intel/openmpi/bin/:$PATH

cd PPP

echo "Job running on "`hostname`

mpirun --bind-to none -np 8 CCC < III.inp > III.log
mpirun --bind-to none -np 8 CCC < III_trajread.inp > III_trajread.log

# calculate mean electrostatic energy from III_trajread.log
if [ -e III_trajread.log ]; then
  total=0
  count=0
  for i in $( grep "ENER EXTERN>" III_trajread.log | awk '{print $4}' ); do
    total=$( echo "scale=3; $total+$i" | bc )
    ((count++))
  done
  mean=$( echo "scale=5; $total / $count" | bc )
  echo "$mean" | bc > mean_E_elec.dat

  # calculate variance (should not exceed 0.5 or we may need to subdivide lambda windows)
  var=0
  for i in $( grep "ENER EXTERN>" III_trajread.log | awk '{print $4}' ); do
    tt=$( echo "scale=5; $i-$mean" | bc )
    tt=$( echo "scale=5; $tt*$tt" | bc )
    var=$( echo "scale=5; $var+$tt" | bc )
  done
  var=$( echo "scale=5; $var/$count" | bc )
  echo "$var" > var_E_elec.dat

fi

