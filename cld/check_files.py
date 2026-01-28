import os

#check for file presence in this path
outpath = "/local/joosep/cld_edm4hep/v1.2.2_key4hep_2025-05-29_CLD_3edac3/"

#pythia card, start seed, end seed
samples = [
    ("p8_ee_ZZ_ecm365",         100000, 100010),
    ("p8_ee_ZZ_tautau_ecm365",  100000, 100010),
    ("p8_ee_ZH_Htautau_ecm240", 200000, 200010),
    ("p8_ee_ttbar_ecm365",      300000, 300010),
    ("p8_ee_WW_ecm365",         400000, 400010),
]

if __name__ == "__main__":
    for sname, seed0, seed1 in samples:
        os.makedirs(f"{outpath}/{sname}/root", exist_ok=True)
        for seed in range(seed0, seed1):
            #check if output file exists, and print out batch submission if it doesn't
            if not os.path.isfile(f"{outpath}/{sname}/root/reco_{sname}_{seed}.root"):
                print("sbatch run_sim.sh {} {}".format(seed, sname)) 
