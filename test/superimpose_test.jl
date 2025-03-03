using AcceleratorLattice, Test

@eles begin
  beginning = BeginningEle(pc_ref = 1e7, species_ref = Species("electron"))
  q1 = Quadrupole(L = 0.6, x_rot_body = 2, ID = "qz", Ks8L = 123, tilt8 = 2, Bn9 = 3, 
                          En1L = 1, Etilt1 = 2, Es2 = 3, Etilt2 = 4)
  q2 = Quadrupole(L = 0.6, Kn1 = -0.3);
  d1 = Drift(L = 1.0);
  lc1 = LCavity(L = 1.0, dE_ref = 2e7, voltage = 10e7, extra_dtime_ref = 1e-8);
  d3 = Drift(L = 1.0);
  m1 = Marker();
  m2 = Marker();
  zs1 = Sextupole(Kn2L = 0.2);
  zs2 = Bend(L = 0.3, angle = pi/2, tilt_ref = pi/2, Kn2L = 0.1, Bs3 = 0.2, En4 = 0.3, Es5L = 0.4)
  zm1 = Marker();
  zm2 = Marker();
  zm3 = Marker();
  zm4 = Marker();
end;

#---------------------------------------------------------------------------------------------------

ln1 = BeamLine([beginning, d1, lc1, d1, d3]);
lat = Lattice([ln1])

sup_zs2 = superimpose!(zs2, eles_search(lat, "d1"), offset = 0.25)
sup_m1 = superimpose!(m1, lat.branch[1], offset = 0, ref_origin = BodyLoc.ENTRANCE_END)
sup_sm1 = superimpose!(zm1, eles_search(lat, "m1"), ref_origin = BodyLoc.ENTRANCE_END)
sup_zm4 = superimpose!(zm4, eles_search(lat, "lc1"), offset = 0.2)
sup_m2 = superimpose!(m2, lat.branch[1], offset = 2.7)
sup_zm2 = superimpose!(zm2, eles_search(lat, "m1"), ref_origin = BodyLoc.CENTER)
sup_zm3 = superimpose!(zm3, eles_search(lat, "m1"), ref_origin = BodyLoc.EXIT_END)

b1 = lat.branch[1]
b2 = lat.branch[2]

@testset "Superimpose1" begin
  @test [e.name for e in b1.ele] == 
               ["beginning",  "zm1",  "zm2",  "m1",  "zm3",  "d1!1",  "zs2", "d1!2",  "lc1!s1",
                "zm4",  "lc1!s2",  "d1!1",  "zs2!s1",  "m2",  "zs2!s2",  "d1!2",  "d3",  "end1"]
  @test [e.name for e in b2.ele] == ["lc1", "zs2"]
  @test b1.ele[9].super_lords  == [b2.ele[1]]
  @test b1.ele[11].super_lords  == [b2.ele[1]]
  @test b1.ele[13].super_lords == [b2.ele[2]]
  @test b1.ele[15].super_lords == [b2.ele[2]]
  @test b2.ele[1].slaves == [b1.ele[9], b1.ele[11]]
  @test b2.ele[2].slaves == [b1.ele[13], b1.ele[15]]
  @test length.([sup_m1, sup_sm1, sup_zs2, sup_zm4, sup_m2, sup_zm2, sup_zm3]) == [1, 1, 2, 1, 1, 1, 1]
  @test [e.slave_status for e in b1.ele] ==
        [Slave.NOT, Slave.NOT, Slave.NOT, Slave.NOT, Slave.NOT, Slave.NOT,
         Slave.NOT, Slave.NOT, Slave.SUPER, Slave.NOT, Slave.SUPER, Slave.NOT, 
         Slave.SUPER, Slave.NOT, Slave.SUPER, Slave.NOT, Slave.NOT, Slave.NOT]
  @test [e.lord_status for e in b1.ele] ==
        [Lord.NOT, Lord.NOT, Lord.NOT, Lord.NOT, Lord.NOT, Lord.NOT,
         Lord.NOT, Lord.NOT, Lord.NOT, Lord.NOT, Lord.NOT, Lord.NOT, 
         Lord.NOT, Lord.NOT, Lord.NOT, Lord.NOT, Lord.NOT, Lord.NOT]
  @test [e.slave_status for e in b2.ele] == [Slave.NOT, Slave.NOT]
  @test [e.lord_status for e in b2.ele] == [Lord.SUPER, Lord.SUPER]

  @test isapprox([b1[9].extra_dtime_ref, b1[11].extra_dtime_ref, b2[1].extra_dtime_ref], 
              [7.0e-9, 3.0e-9, 10.0e-9], rtol = 1e-14)
  @test isapprox([b1[9].time_ref, b1[11].time_ref, b2[1].time_ref], 
          [3.3399931243559422e-9, 1.2676210973138516e-8, 3.3399931243559422e-9], rtol = 1e-14)
  @test isapprox([b1[9].time_ref_downstream, b1[11].time_ref_downstream, b2[1].time_ref_downstream], 
          [ 1.2676210973138516e-8, 1.6677084590208777e-8, 1.6677084590208777e-8], rtol = 1e-14)
  @test isapprox([b1[9].dE_ref, b1[11].dE_ref, b2[1].dE_ref], [1.4e7, 6.0e6, 2.0e7], rtol = 1e-14)
  @test isapprox([b1[9].E_tot_ref, b1[11].E_tot_ref, b2[1].E_tot_ref], 
          [1.0013047484537676e7, 2.4013047484537676e7, 1.0013047484537676e7], rtol = 1e-14)
  @test isapprox([b1[9].voltage, b1[11].voltage, b2[1].voltage], [7.0e7, 3.0e7, 10.0e7], rtol = 1e-14)
  @test isapprox([b1[9].gradient, b1[11].gradient, b2[1].gradient], [1.0e8, 1.0e8, 1.0e8], rtol = 1e-14)

  ##@test 
end

#---------------------------------------------------------------------------------------------------

#ln2 = BeamLine([beginning


#@testset "Superimpose2" begin



#end


# getproperty. L, s, s_downstream, name, multipoles, reference energy
# superimpose at boundary
# Make sure superimpose at branch start is not before beginning element.
# Transfer of parameters between lord/slave especially multipoles
# LCavity with marker
# UnionEle

print("")  # To surpress trailing garbage output
