import os

#check for file presence in this path
outpath = "/local/joosep/cld_edm4hep/v1.2.1_key4hep_2025-05-29_CLD_02ff56/"

#pythia card, start seed, end seed
samples = [
    ("p8_ee_ZZ_ecm365",         100000, 100010),
]

if __name__ == "__main__":
    for sname, seed0, seed1 in samples:
        os.makedirs(f"{outpath}/{sname}/root", exist_ok=True)
        for seed in range(seed0, seed1):
            #check if output file exists, and print out batch submission if it doesn't
            if not os.path.isfile(f"{outpath}/{sname}/root/reco_{sname}_{seed}.root"):
                print("sbatch run_sim.sh {} {}".format(seed, sname)) 
