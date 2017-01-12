#!/bin/bash

# Mike Devereux. Jan 2017.
#
# Script to run manual CHARMM thermodynamic integration for solvation free energy of a solute
# molecule in a solvent box for a given parameter set. Trajectories are run at the midpoint of
# each Lambda window. For electrostatic contributions, delta G is evaluated by running a
# trajectory at a given Lambda, then reading in the CHARMM dcd file and evaluating the energy
# at Lambda=1 for each step and using the mean Lambda=1 energy as dG for that window (see Eq.
# 14, Bereau et al., JCTC, 2013, 9, 5450-5459)
#
#
#---------------------------------------------------------------------------------------------

# Set some variables:



D_LAMBDA=0.1  # size of lambda window
NSTEPS=20000  # number of integration steps per lambda window
TMPL=/opt/cluster/programs/ti-script
CHMM=/home/devereux/c40b1-dcm/exec/gnu_M/charmm

mtpl=0
dcm=0


######################################################################################################
#
#                                     FUNCTIONS
#

function monitor_job {
  printf "\n\n\n"
  while true; do
    sleep 5
    nrun=`qstat -u $USER | grep "ti." | sed -n $=`
    tim=`date +%H:%M`
    day=`date +%d/%m/%y`
    if [ -z $nrun ]; then
      printf "\n\n\n \e[1;32mAll jobs finished at $tim on $day, checking output files...\e[0m\n\n\n"
      break
    fi
    echo -ne "$nrun / $NWIN Jobs Still Running (last checked $tim)     \r"
    for i in {1..60}; do
      sleep 1
      echo -ne "$nrun / $NWIN Jobs Still Running (last checked $tim) .        \r"
      sleep 1
      echo -ne "$nrun / $NWIN Jobs Still Running (last checked $tim) ..       \r"
      sleep 1
      echo -ne "$nrun / $NWIN Jobs Still Running (last checked $tim) ...      \r"
      sleep 1
      echo -ne "$nrun / $NWIN Jobs Still Running (last checked $tim) ....     \r"
      sleep 1
      echo -ne "$nrun / $NWIN Jobs Still Running (last checked $tim) .....    \r"
    done
  done
  echo -ne '\n'
}


function phelp {
  printf "\n\n Usage: ti.sh [-mtp [punchfile] -top [topfile]]\n"
  printf "              [-dcm [chgfile] -top [topfile]]\n\n"
  printf " -dcm:\t\t request a DCM run\n -mtp:\t\t request an MTP run\n"
  printf " -top:\t\t define topology file for solute\n"
  printf " -lpun:\t\t define solute punch file for MTP run\n\n\n"
  exit
}

function resub() {
  cd lambda_$LAMBDA
  qsub lambda_$LAMBDA.sh
  cd ..
}

###############################################################################################


# Parse arguments

if [ $# -eq 0 ]; then
  phelp
fi

while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    -mtp)
    mtpl=1
    PUNFILE=$2
    if [ -z $PUNFILE ]; then
      printf "\e[1;31mError: Punch file must be specified. Type ti.sh -h for help.\e[0m\n\n"
      exit
    fi
    if ! [ -e $PUNFILE ]; then
      printf "\e[1;31mError: Punch file $PUNFILE not found in path `pwd`\e[0m\n\n"
      exit
    fi
    if [ $dcm -eq 1 ]; then
      printf "\e[1;31mError: options DCM and MTP are mutually exclusive\e[0m\n\n"
      exit
    fi
    shift # past argument
    ;;
    -dcm)
    dcm=1
    DCMFILE=$2
    if [ -z $DCMFILE ]; then
      printf "\e[1;31mError: Charge file must be specified. Type ti.sh -h for help.\e[0m\n\n"
      exit
    fi
    if ! [ -e $DCMFILE ]; then
      printf "\e[1;31mError: DCM charge file $DCMFILE not found in path `pwd`\e[0m\n\n"
      exit
    fi
    if [ $mtpl -eq 1 ]; then   
      printf "\e[1;31mError: options DCM and MTP are mutually exclusive\e[0m\n\n"
      exit
    fi
    shift # past argument
    ;;
    -top)
    TOPOL="$2"  # topology file for solute
    if [ -z $TOPOL ]; then
      printf "\e[1;31mError: Topology file must be specified. Type ti.sh -h for help.\e[0m\n\n"
      exit
    fi
    if ! [ -e $TOPOL ]; then
      printf "\e[1;31mError: Topology file $TOPOL not found in path `pwd`\e[0m\n\n"
      exit
    fi
    shift # past argument
    ;;
    -lam)
    D_LAMBDA="$2" # lambda window size
    if [ -z $D_LAMBDA ]; then
      printf "\e[1;31mError: -lam option requires lambda window size to be specified\e[0m\n\n"
      exit
    fi
    printf " LAMBDA window size set to $D_LAMBDA\n\n"
    shift # past argument
    ;;
    -h)
      phelp
    ;;
    *)
      printf "\e[1;31mError: unkown option $1. Type ti.sh -h for help.\e[0m\n\n"
      exit
    ;;
esac
shift # past argument or value
done

# Check consistency of arguments

if [ $dcm -eq 0 ] && [ $mtpl -eq 0 ]; then   
  printf "\e[1;31mError: either DCM or MTP must be selected\e[0m\n\n"
  exit
fi

if [ $dcm -eq 1 ]; then
  printf "\e[1;31mError: DCM not yet implemented\e[0m\n\n"
  exit
fi

if [ -z $TOPOL ]; then
  printf "\e[1;31mError: Topology file not specified. Type ti.sh -h for help.\e[0m\n\n"
  exit
fi

printf "\e[1;32m\n\n\n\tSTARTING THERMODYNAMIC INTEGRATION SCRIPT AT `date`\e[0m\n\n"


# check that lambda window makes sense:
TMP=`bc <<< "scale = 4; 1 / $D_LAMBDA"`
NWIN=`bc <<< "scale = 0; 1 / $D_LAMBDA"`
TMP2=`bc <<< "scale = 4; $TMP / $NWIN"`

if [ `bc <<< "$TMP2 == 1.0"` = 0 ]; then
  printf "\e[1;31mError: D_LAMBDA must form NWIN complete windows between 0.0 and 1.0 (currently $TMP)\e[0m\n\n"
  exit 0
fi

printf " $NWIN lambda windows will be run\n\n"



# check that templates folder exists in directory "$TMPL":
if ! [ -e $TMPL/templates ]; then
  printf "\e[1;31mError: templates/ folder containing CHARMM template files does not exist in directory\e[0m\n\n"
  exit 0
else
  printf " Templates folder exists at $TMPL\n\n"
fi


# check that no folders named lambda_* already exist:
if ( ls -1p | grep "lambda_" | grep "/" > /dev/null); then
  printf "\e[1;31mFolders named lambda_xxxx already exist in this directory. Please remove them and restart\e[0m\n\n"
  exit 0
fi


# Create some folders:

printf " Creating lambda_* subfolders in directory `pwd`\n\n"

LAMBDA1=`bc <<< "scale=4; $D_LAMBDA / 2"`

for i in $(seq 1 $NWIN); do

  LAMBDA=`bc <<< "scale = 4; $D_LAMBDA * $i - $LAMBDA1"`
  mkdir lambda_$LAMBDA

done

printf " Creating common/ folder for common CHARMM files\n\n"
if [ -e common ]; then
  printf "\e[1;33m Warning: common/ folder containing CHARMM common files already exists in this directory, overwriting...\e[0m\n\n"
fi
mkdir -p common || exit 0

# copy CHARMM topology files for run to common folder
cp $TMPL/templates/*.top common || exit 0

# copy solute topology file to common folder
cp $TOPOL common || exit 0

# copy CHARMM parameter files for run to common folder
cp $TMPL/templates/*.par common || exit 0

# copy PDB files for run to common folder
cp $TMPL/templates/*.pdb common || exit 0

# copy stream file to common folder
cp $TMPL/templates/*.str common || exit 0

# copy zeroed topology file to common folder
printf " Creating zeroed topology file in common folder\n\n"
$TMPL/zero_topology.pl $TOPOL; mv zeroed.top common || exit 0

if [ $mtpl -eq 1 ]; then  
  # copy lpun files to common folder
  [ -e $TMPL/templates/*.lpun ] && cp $TMPL/templates/*.lpun common 
  cp $PUNFILE common/lambda_1.0.lpun || exit 0
  printf " Writing scaled input files and submission scripts\n\n"
  # scale parameters in lpun file:
  for i in $(seq 1 $NWIN); do
    LAMBDA=`bc <<< "scale = 4; $D_LAMBDA * $i - $LAMBDA1"`
    sed "s/LLL/$LAMBDA/g" $TMPL/templates/tmpl-mtpl.inp > lambda_$LAMBDA/lambda_$LAMBDA.inp
    sed -i "s/SSS/$NSTEPS/g" lambda_$LAMBDA/lambda_$LAMBDA.inp
    sed "s/LLL/$LAMBDA/g" $TMPL/templates/tmpl-mtpl-trajread.inp > lambda_$LAMBDA/lambda_$LAMBDA"_trajread.inp"
  # create submission script
    sed "s/NNN/ti$LAMBDA/g" $TMPL/templates/tmpl-mtpl.sh > lambda_$LAMBDA/lambda_$LAMBDA.sh
    sed -i "s:CCC:$CHMM:g" lambda_$LAMBDA/lambda_$LAMBDA.sh
    sed -i "s:PPP:`pwd`/lambda_$LAMBDA/:g" lambda_$LAMBDA/lambda_$LAMBDA.sh
    sed -i "s:III:lambda_$LAMBDA:g" lambda_$LAMBDA/lambda_$LAMBDA.sh
    chmod ug+x lambda_$LAMBDA/lambda_$LAMBDA.sh

  # Run charmm job
    printf " \e[1;32mSubmitting job lambda_$LAMBDA.inp\e[0m\n\n\n"
    cd lambda_$LAMBDA
    qsub lambda_$LAMBDA.sh
    cd ..
  done
fi

printf " Submitted jobs at `date`\n\n"

monitor_job

printf " Checking to see whether all jobs finished successfully\n\n"


# Check to see whether jobs completed successfully
for j in 1 2; do
  if [ $mtpl -eq 1 ]; then
    for i in $(seq 1 $NWIN); do
      LAMBDA=`bc <<< "scale = 4; $D_LAMBDA * $i - $LAMBDA1"`
      # Did trajectory run?
      if ! [ -e lambda_$LAMBDA/lambda_$LAMBDA.log ]; then
        printf "\n\n\n \e[1;31m Job lambda_$LAMBDA.inp has no log file.\e[0m\n\n"
        if [ $j -eq 2 ]; then
          printf "\n\n\n \e[1;31m Exiting script, please check for problems with job submission.\e[0m\n\n\n"
          exit
        fi
        LOG=lambda_$LAMBDA.log
        resub
        continue 
      fi
      # Did analysis job run?
      if ! [ -e lambda_$LAMBDA/lambda_$LAMBDA"_trajread.log" ]; then
        printf "\n\n\n \e[1;31m Job lambda_"$LAMBDA"_trajread.inp has no log file.\e[0m\n\n"
        if [ $j -eq 2 ]; then
          printf "\n\n\n \e[1;31m Exiting script, please check for problems with job submission.\e[0m\n\n\n"
          exit
        fi
        LOG=lambda_$LAMBDA"_trajread.log"
        resub
        continue
      fi
      # Did trajectory finish correctly?
      if ! ( grep "NORMAL TERMINATION" lambda_$LAMBDA/lambda_$LAMBDA.log > /dev/null ); then
        if [ $j -eq 2 ]; then
          printf "\n\n\n \e[1;31m Job lambda_$LAMBDA.log crashed for second time. Exiting script, please examine CHARMM output file lambda_$LAMBDA.log for more information.\e[0m\n\n\n"
          exit 
        fi
        printf "\n\n\n \e[1;31m Job lambda_$LAMBDA.log appears to have crashed. Moving log file to lambda_$LAMBDA/lambda_$LAMBDA.log.crash and resubmitting\e[0m\n\n\n"
        LOG=lambda_$LAMBDA.log
        mv lambda_$LAMBDA/$LOG lambda_$LAMBDA/$LOG.crash
        resub
        continue
      else
        printf " Job lambda_$LAMBDA.inp finished successfully\n"
      fi
      # Did analysis job finish correctly?
      if ! ( grep "NORMAL TERMINATION" lambda_$LAMBDA/lambda_$LAMBDA"_trajread.log" > /dev/null ); then
        if [ $j -eq 2 ]; then
          printf "\n\n\n \e[1;31m Job lambda_"$LAMBDA"_trajread.log crashed for second time. Exiting script, please examine CHARMM output file lambda_"$LAMBDA"_trajread.log for more information.\e[0m\n\n\n"
          exit 
        fi
        printf "\n\n\n \e[1;31m Job lambda_"$LAMBDA"_trajread.log appears to have crashed. Moving log file to lambda_$LAMBDA/lambda_"$LAMBDA"_trajread.log.crash and resubmitting\e[0m\n\n\n"
        LOG=lambda_$LAMBDA"_trajread.log"
        mv lambda_$LAMBDA/$LOG lambda_$LAMBDA/$LOG.crash
        resub
        continue
      else
        printf " Job lambda_"$LAMBDA"_trajread.inp finished successfully\n"
      fi
    done
    monitor_job
  fi
done

printf "\n\n \e[1;32mAll jobs completed successfully\e[0m\n\n\n"

# If we reach here, all jobs should have finished successfully (with "NORMAL TERMINATION"), so we can
# gather results from "delta_G.dat" in each folder

printf " Gathering free energies for each window from mean_E_elec.dat files\n\n\n"
[ -e delta_G_elec.dat ] && rm delta_G_elec.dat
dG=0
for i in $(seq 1 $NWIN); do
  LAMBDA=`bc <<< "scale = 4; $D_LAMBDA * $i - $LAMBDA1"`
  eel=`cat lambda_$LAMBDA/mean_E_elec.dat`
  dGi=$( echo $eel*$D_LAMBDA | bc )
  var=`cat lambda_$LAMBDA/var_E_elec.dat`
  printf " Lambda $LAMBDA:  delta_G(elec) = $dGi  variance = $var\n"
  dG=$( echo $dG+$dGi | bc )

  if (( $(echo "$var > 0.5" |bc -l) )); then
    printf "\e[1;33m Warning: Variance $var for lambda=$LAMBDA is greater than 0.5. Consider reducing the lambda window size with -lam option.\e[0m\n\n"
  fi
done

printf "\n\n \e[1;32mTotal delta_G(elec) = $dG kcal/mol\e[0m\n\n\n"
echo $dG > delta_G_elec.dat

printf " Exiting gracefully, final delta_G written to `pwd`/delta_G_elec.dat\n"
printf " Suggestions / bug reports to Michael.Devereux@unibas.ch\n\n"

