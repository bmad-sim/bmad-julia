using AcceleratorLattice

@ele begin_ln2 = BeginningEle(pc_ref = 1e7, species_ref = Species("electron"))
@ele begin_fodo = BeginningEle(E_tot_ref = 1.23456789012345678e3, s = 0.3, species_ref = Species("photon"))
#@ele qf = Quadrupole(L = 0.6, K2 = 0.3, tilt0 = 1, x_rot = 2, alias = "qz", Es8L = 123, Etilt8 = 2)
@ele qf = Quadrupole(L = 0.6, x_rot = 2, alias = "qz", Ks8L = 123, tilt8 = 2)
@ele qd = Quadrupole(L = 0.6, Kn1 = -0.3)
@ele d = Drift(L = 0.4)
@ele z1 = Bend(L = 1.2, angle = 0.001)
@ele z2 = Sextupole(Kn2L = 0.2)
@ele m1 = Marker()


ln1 = beamline("ln1", [qf, d])
ln2 = beamline("ln2", [qd, d, qd], geometry = closed, multipass = true)
fodo = beamline("fodo", [z1, z2, -2*ln1, m1, m1, ln2, reverse(qf), reverse(ln2), reverse(beamline("sub", [qd, ln1]))])

lat = Lattice("mylat", [beamline("fodo2", [begin_fodo, fodo]), beamline("ln2", [begin_ln2, ln2])])

@ele b1 = Bend(L = 0.2, angle = 0.1)
superimpose!(b1, lat.branch[2].ele[3], offset = 0.2, ref_origin = entrance_end);

lat