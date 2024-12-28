#---------------------------------------------------------------------------------------------------
# superimpose!

"""
    function superimpose!(super_ele::Ele, ref; ele_origin::BodyLoc.T = BodyLoc.CENTER, 
                          offset::Real = 0, ref_origin::BodyLoc.T = BodyLoc.CENTER, 
                          wrap::Bool = true) where T <: Union{Branch, Ele, Vector{Branch}, Vector{Ele}}

Superimpose a copy (or copies) of the element `super_ele` on a lattice (or lattices).
If `ref` is a scaler, one superposition is done. 
If `ref` is a vector, one superposition is done per element of `ref`.
The set of `ref` elements do not all have to be contained within a single lattice.
See the AcceleratorLattice manual for more details.

Returned is a vector of superimposed elements.

### Input
- `super_ele`     Element to be copied and the copies to be superimposed on the lattice.
                  `Drift` and `BeginningEle` type elements are not allowed.

- `ref`           Reference element or element array that determine where superposition is done.
                  A superposition is done for each element in an array. If `ref` is a `Branch`
                  or array of Branches, the reference element is taken to be the `BeginningEle`
                  element at the beginning of the branch.

- `ele_origin`    Location of the origin point on the `super_ele` in body coordinates. That is,

- `offset`        Offset distance between the `ele_origin` and the `ref_origin`.

- `ref_origin`    Location of the reference origin point on the `ref` element.

- `wrap`          Only relavent if the superimposed element has an end that extends beyond the 
starting or ending edge of the branch. If true (default), wrap the element around the
branch so that the element's upstream edge before the branch end edge and the element's 
downstream edge after the branch start edge. If `wrap` = false, extend the lattice to accommodate.


### Notes
- Valid `BodyLoc.T` values are:
  - BodyLoc.ENTRANCE_END
  - BodyLoc.CENTER
  - BodyLoc.EXIT_END

- Zero length elements in the superposition region will be left alone.

- Superimposing an element on top of a non-`Drift` element produces a `UnionEle` `super_slave`
with appropriate `super_lord` elements.

- The superposition location is determined with respect to the `local` coordinates of the `ref`.
Thus, a positive `offset` will displace the superposition location downstream if `ref` has
a normal orientation and vice versa for a reversed orientation.

- When `offset` = 0, for zero length `super_ele` elements the superposition location is at the 
entrance end of `ref` except if `ref_origin` is set to `BodyLoc.EXIT_END` in which case the 
superposition location is at the exit end of `ref`.

- The superimposed element will inherit the orientation of the `ref` element.
""" superimpose!

function superimpose!(super_ele::Ele, ref::T; ele_origin::BodyLoc.T = BodyLoc.CENTER, 
                      offset::Real = 0, ref_origin::BodyLoc.T = BodyLoc.CENTER, 
                      wrap::Bool = true) where {E <: Ele, T <: Union{Branch, Ele, Vector{Branch}, Vector{E}}}
  if typeof(ref) == Branch
    ref_ele = ref.ele[1]
  else
    ref_ele = ref
  end

  if length(collect(ref_ele)) == 0
    println("NOTE! No reference element found for superposition of $(ele_name(super_ele)) so no superposition done.")
    return nothing
  end
  
  super_list = []
  lat_list = []

  for this_ref in collect(ref_ele)
    if typeof(this_ref) == Branch
      ref_ele = this_ref.ele[1]
    else
      ref_ele = this_ref
    end

    # Get insertion branch
    if !haskey(ref_ele.pdict, :branch)
      error("Reference element: $(ref_ele.name) does is not part of a lattice.")
    end
    branch = ref_ele.branch
    if branch.type <: LordBranch 
      branch = ref_ele.slaves[1].branch
      ref_ix_ele = ref_ele.slaves[1].ix_ele
    else
      ref_ix_ele = ref_ele.ix_ele
    end

    lat = branch.lat
    if lat ∉ lat_list
      push!(lat_list, lat)
      lat.pdict[:old_autobookkeeping] = lat.autobookkeeping
      lat.autobookkeeping = false
      lat.record_changes = false
    end

    L_super = super_ele.L
    offset = offset * ref_ele.orientation
    # Convert from body entrance/exit to up/dowstream
    machine_ref_origin = machine_location(ref_origin, ref_ele.orientation)  
    machine_ele_origin = machine_location(ele_origin, ref_ele.orientation)

    # Insertion of zero length element with zero offset at edge of an element.
    if L_super == 0 && offset == 0 
      if machine_ref_origin == Loc.UPSTREAM_END || (machine_ref_origin == Loc.CENTER && ref_ele.L == 0)
        ix_insert = max(ref_ix_ele, 2)
        push!(super_list, insert!(branch, ix_insert, super_ele))
        continue
      elseif machine_ref_origin == Loc.DOWNSTREAM_END 
        ix_insert = min(ref_ix_ele+1, length(ref_ele.branch.ele))
        push!(super_list, insert!(branch, ix_insert, super_ele))
        continue
      end
    end

    # Super_ele end locations: s1 and s2.
    if branch.type <: LordBranch
      if machine_ref_origin == Loc.UPSTREAM_END; s1 = ref_ele.slaves[1].s
      elseif machine_ref_origin == Loc.CENTER; s1 = 0.5 * (ref_ele.slaves[1].s + ref_ele.slaves[end].s_downstream)
      else;                                    s1 = ref_ele.slaves[end].s_downstream
      end
    else    # Not a lord branch
      if machine_ref_origin == Loc.UPSTREAM_END; s1 = ref_ele.s
      elseif machine_ref_origin == Loc.CENTER;   s1 = 0.5 * (ref_ele.s + ref_ele.s_downstream)
      else;                                      s1 = ref_ele.s_downstream
      end
    end

    if machine_ele_origin == Loc.UPSTREAM_END; s1 = s1 + offset
    elseif machine_ele_origin == Loc.CENTER;   s1 = s1 + offset - 0.5 * L_super
    else;                                      s1 = s1 + offset - L_super
    end

    s2 = s1 + L_super

    # If super_ele has zero length just insert it.
    if L_super == 0
      if machine_ref_origin == Loc.DOWNSTREAM_END
        ele_at, _ = split!(branch, s1, select = Select.DOWNSTREAM, ele_near = ref_ele)
      else
        ele_at, _ = split!(branch, s1, select = Select.UPSTREAM, ele_near = ref_ele)
      end
      push!(super_list, insert!(branch, ele_at.ix_ele, super_ele))
      continue
    end

    # Below is for a super_ele that has a nonzero length
    branch_len = branch.ele[end].s_downstream - branch.ele[1].s

    if s1 < branch.ele[1].s
      if wrap
        s1 = s1 + branch_len
      else
        @ele drift = Drift(L = branch.ele[1].s - s1)
        insert!(branch, 2, drift)
      end
    end

    if s2 > branch.ele[end].s_downstream
      if wrap
        s2 = s2 - branch_len
      else
        @ele drift = Drift(L = s2 - branch.ele[end].s_downstream)
        insert!(branch.ele, length(branch.ele), drift)
      end
    end

    # Split points are chosen to avoid creating elements with non-zero length below the minimum.
    # And super_lord length will be adjusted accordingly.
    ele1 = ele_at_s(branch, s1, select = Select.UPSTREAM, ele_near = ref_ele)
    ele2 = ele_at_s(branch, s2, select = Select.DOWNSTREAM, ele_near = ref_ele)

    min_len = min_ele_length(branch.lat)

    if abs(ele1.s - s1) < min_len
      s1 = ele1.s
      super_ele.L = super_ele.L + s1 - ele1.s
    elseif abs(ele1.s_downstream - s1) < min_len
      s1 = ele1.s_downstream
      super_ele.L = super_ele.L + s1 - ele1.s_downstream
    end

    if abs(ele2.s - s2) < min_len
      s2 = ele2.s
      super_ele.L = super_ele.L + ele2.s - s2
    elseif abs(ele2.s_downstream - s2) < min_len
      s2 = ele2.s_downstream
      super_ele.L = super_ele.L + ele2.s_downstream - s2
    end

    # `select` is set to minimize number of elements in the superposition region.
    # The superposition region is from beginning of ele1 to the beginning of ele2.

    ele2, _ = split!(branch, s2, select = Select.UPSTREAM)  # Notice that s2 split must be done first!
    ele1, _ = split!(branch, s1, select = Select.DOWNSTREAM)

    # If there are just drifts here then no superimpose needed.
    # Note: In this case there cannot be wrap around.

    all_drift = true
    n_ele = 0
    for ele in Region(ele1, ele2, false)
      n_ele += 1
      if typeof(ele) != Drift; all_drift = false; end
    end

    #

    if all_drift
      ix_super = ele1.ix_ele
      super_ele = set!(branch, ix_super, super_ele)
      push!(super_list, super_ele)
      if n_ele > 1; deleatat!(branch.ele, ix_super+1:ix_super+n_ele-1); end
      if typeof(branch.ele[ix_super-1]) == Drift; set_drift_slice_names(branch.ele[ix_super-1]); end
      if typeof(branch.ele[ix_super+1]) == Drift; set_drift_slice_names(branch.ele[ix_super+1]); end
      continue 
    end

    # Here if a super_lord element needs to be constructed.
    lord_list = [] 
    sbranch = branch.lat.branch["super"]

    lord1 = push!(sbranch, super_ele)
    lord1.lord_status = Lord.SUPER
    lord1.pdict[:slaves] = Ele[]
    push!(lord_list, lord1)
    push!(super_list, lord1)

    for ele in Region(ele1, ele2, false)
      if ele.L == 0; continue; end
      ix_ele = ele.ix_ele

      if typeof(ele) == Drift
        ele2 = set!(branch, ix_ele, super_ele)
        ele2.slave_status = Slave.SUPER
        ele2.L = ele.L
        ele2.pdict[:super_lords] = Vector{Ele}([lord1])
        push!(lord1.slaves, ele2)
        set_drift_slice_names(ele)

      elseif ele.slave_status != Slave.SUPER
        lord2 = push!(sbranch, ele)
        lord2.lord_status = Lord.SUPER
        push!(lord_list, lord2)

        slave = set!(branch, ix_ele, UnionEle(name = "", L = ele.L, super_lords = Vector{Ele}([lord1])))
        slave.slave_status = Slave.SUPER
        lord2.pdict[:slaves] = Vector{Ele}([slave])
        push!(slave.pdict[:super_lords], lord2)
        push!(lord1.pdict[:slaves], slave)

      else  # Is super_slave and not Drift
        if typeof(ele) != UnionEle   # That is, has a single super_lord
          set!(branch, ix_ele, UnionEle(name = "", L = ele.L, super_lords = ele.super_lords))
          old_lord = ele.super_lords[1]
          for (ix, slave) in enumerate(old_lord.slaves)
            if slave === ele; old_lord.slaves[ix] = branch.ele[ix_ele]; end
          end
        end

        slave = branch.ele[ix_ele]
        push!(slave.pdict[:super_lords], lord1)
        push!(lord1.pdict[:slaves], slave)
      end
    end

    index_and_s_bookkeeper!(branch)

    for lord in lord_list
      set_super_slave_names!(lord)
      if length(lord.slaves) == 1; continue; end
      initial_superlord_bookkeeping(lord)
    end

  end   # for this_ref in collect(ref)

  for lat in lat_list
    lat.autobookkeeping = lat.old_autobookkeeping
    pop!(lat.pdict, :old_autobookkeeping)
    lat.record_changes = true
    if lat.autobookkeeping; bookkeeper!(lat); end
  end

  return super_list
end

#---------------------------------------------------------------------------------------------------
# initial_superlord_bookkeeping

"""
  Internal: initial_superlord_bookkeeping(lord::Ele)

Internal routine for the initial bookkeeping of a newly formed superlord element.
The only parameters that need bookkeeping are ones that are not the same in the lord and the slave.
""" initial_superlord_bookkeeping

function initial_superlord_bookkeeping(lord::Ele)
  if lord.L == 0; return; end

  for (ixs, slave) in enumerate(lord.slaves)
    # UnionEle elements don't have any parameters to be bookkeeped
    if typeof(slave) == UnionEle; continue; end
    L_rel = slave.L / lord.L

    # All non-UnionEle slaves will only have one lord.
    # dE_ref bookkeeping
    if lord.dE_ref != 0
      slave.dE_ref = lord.dE_ref * L_rel
    end

    # Multipole with length bookkeeping
    if haskey(lord.pdict, :BMultipoleGroup)
      for (ix, pole) in enumerate(lord.BMultipoleGroup.pole)
        if !pole.integrated; continue; end 
        slave.BMultipoleGroup[ix].Kn = pole.Kn * L_rel
        slave.BMultipoleGroup[ix].Ks = pole.Ks * L_rel
        slave.BMultipoleGroup[ix].Bn = pole.Bn * L_rel
        slave.BMultipoleGroup[ix].Bs = pole.Bs * L_rel
      end
    end

    if haskey(lord.pdict, :EMultipoleGroup)
      for (ix, pole) in enumerate(lord.EMultipoleGroup.pole)
        if !pole.integrated; continue; end 
        slave.EMultipoleGroup[ix].En = pole.En * L_rel
        slave.EMultipoleGroup[ix].Es = pole.Bs * L_rel
      end
    end

    # Bend bookkeeping
    if haskey(lord.pdict, :BendGroup)
      slave.angle = lord.angle * L_rel

      if ixs < length(lord.slaves)
        slave.e2 = 0
        slave.e2_rect = 0.5 * slave.angle
      end

      if ixs > 1
        slave.e1 = 0
        slave.e1_rect = 0.5 * slave.angle
      end

      ele.g == 0 ? ele.L_chord = L : ele.L_chord = 2 * sin(ele.angle/2) / ele.g 
    end

    # Misalignment bookkeeping
    if haskey(lord.pdict, :AlignmentGroup)
      dL = 0.5 * slave.L + slave.s - lord.s

      if haskey(lord.pdict, :BendGroup)
        # Need transformation from lord alignment point to slave alignment point
        # Translate from lord alignment point to beginning of lord point
        floor = FloorPositionGroup(r = [0, 0, -0.5*lord.l_chord])
        # Rotate from z parallel to lord chord to z tangent to bend curve.
        if lord.ref_tilt != 0
          q = []
        end
        # On the bend curve: From beginning of lord point to beginning of slave point
        # From z tangent to bend curve to z parallel to slave chord.
        # Translate from beginning of slave point to slave alignment point.
        # Apply total transformation of AlignmentGroup.

      else
        slave.r_floor = lord.r_floor + dL * rot(lord.q_floor, [0.0, 0.0, dL])
      end
    end
  end
end

