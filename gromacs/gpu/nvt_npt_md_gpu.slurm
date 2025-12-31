#!/bin/bash
# GPU-accelerated GROMACS MD workflow (NVT → NPT → Production)
# Designed for SLURM clusters with NVIDIA GPUs
# Features: GPU PME offload, checkpointing, job chaining

#SBATCH --job-name=jz4_gpu_md
#SBATCH --partition=compute
#SBATCH --gres=gpu:1
#SBATCH --cpus-per-task=32
#SBATCH --mem=200G
#SBATCH --time=96:00:00
#SBATCH --output=md_gpu_%j.out
#SBATCH --error=md_gpu_%j.err

cd $SLURM_SUBMIT_DIR

# Path to GPU-enabled GROMACS container (edit before use)
GROMACS_SIF="/path/to/gromacs_container.sif"

echo "=== GPU MD Job Started ==="
echo "Using GROMACS Container: $GROMACS_SIF"

# NVT
apptainer exec --nv --bind /mnt/beegfs \
  $GROMACS_SIF \
  gmx grompp -f nvt.mdp -c em.gro -r em.gro -p topol.top -n index.ndx -o nvt_gpu.tpr -maxwarn 2

apptainer exec --nv --bind /mnt/beegfs \
  $GROMACS_SIF \
  gmx mdrun -deffnm nvt_gpu -ntomp 12 -nb gpu -pme gpu -pin on -cpt 30 -maxh 23.5 -v

# NPT
apptainer exec --nv --bind /mnt/beegfs \
  $GROMACS_SIF \
  gmx grompp -f npt.mdp -c nvt_gpu.gro -t nvt_gpu.cpt -r nvt_gpu.gro -p topol.top -n index.ndx -o npt_gpu.tpr -maxwarn 2

apptainer exec --nv --bind /mnt/beegfs \
  $GROMACS_SIF \
  gmx mdrun -deffnm npt_gpu -ntomp 12 -nb gpu -pme gpu -pin on -cpt 30 -maxh 23.5 -v

# Production
apptainer exec --nv --bind /mnt/beegfs \
  $GROMACS_SIF \
  gmx grompp -f md.mdp -c npt_gpu.gro -t npt_gpu.cpt -p topol.top -n index.ndx -o full_md_gpu.tpr -maxwarn 2

apptainer exec --nv --bind /mnt/beegfs \
  $GROMACS_SIF \
  gmx mdrun -deffnm full_md_gpu -ntomp 12 -nb gpu -pme gpu -pin on -cpt 30 -maxh 23.5 -v

echo "=== GPU MD Complete ==="
