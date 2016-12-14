!SUBROUTINE TO CONSTRUCT CARTESIAN GRID
SUBROUTINE construct_grid()

    USE class_geometry
    USE initialise
    USE electron_scattering

    IMPLICIT NONE

    INTEGER ::  nclumps_tot                 !theoretical number of clumps calculated from filling factor
    INTEGER ::  nclumps                     !actual number of clumps used (increased over iterations
                                            !until within 99.5% of theoretical number)
    INTEGER ::  ixx,iyy,izz                 !mothergrid loop counters
    INTEGER ::  iG                          !cell ID
    INTEGER ::  loop                        !loop counter for clump iterations
    !INTEGER ::  numpG                       !photon number density in each cell
    INTEGER ::  isGx,isGy,isGz              !subgrid loop counters
    INTEGER ::  iS,iSG                      !iS = number of subgrid, iSG = ID of cell in subgrid

    REAL    ::  SF,SF2,SFndust              !scale factors used for normalising
    REAL    ::  M_icm                       !mass of the inter clump medium (ICM)
    REAL    ::  m                           !calculated mass of dust using densities and vols to check correct
    REAL    ::  h,micm,mcl,prob
    REAL    ::  pp
    REAL    ::  rhodG,ndust
    REAL    ::  r(mothergrid%totcells)
    REAL    ::  rho_in                      !density at inner radius (for total dust in smooth distribution)
    REAL    ::  rho_in_icm                  !density at inner radius for dust not in clumps in smooth distribution
    REAL    ::  m_clump                     !mass of a clump
    REAL    ::  msub                        !mass in grid replaced by clumps
    REAL    ::  clump_dens                  !density of individual clump
    REAL    ::  cellno
    REAL    ::  ES_const
    INTEGER :: test

    ALLOCATE(grid_cell(mothergrid%totcells))

    ALLOCATE(tmp(nu_grid%n_bins,1))
    ALLOCATE(grid(mothergrid%ncells(1)+mothergrid%ncells(2)+mothergrid%ncells(3)))
    ALLOCATE(NP(mothergrid%totcells,1))
    ALLOCATE(NP_BIN(nu_grid%n_bins))
    ALLOCATE(RSh(n_shells+1,2))

    tmp=0
    grid=0
    NP=0
    NP_BIN=0
    RSh=0


    !initialise everything to 0
    nclumps_tot=0
    nclumps=0
    M_icm=0
    m=0
    micm=0
    mcl=0
    ncl=0
    prob=0
    pp=0
    rhodG=0
    ndust=0
    r=0
    h=0

!!do something with this!
    call N_e_const(ES_const)

!    !open files to write gridcell coords to (in cm)
!    !OPEN(31,file='grid_values.in')
!    OPEN(32,file='grid.in')

    !calculate useful distances
!    tot_vol=1000*4*pi*(dust_geometry%R_max**3-dust_geometry%R_min**3)/3 !in e42cm^3

    PRINT*,'total volume of supernova in e42cm^3',tot_vol

!    mothergrid%cell_width(1)=(mothergrid%x_max-mothergrid%x_min)/mothergrid%ncells(1)
!    mothergrid%cell_width(2)=(mothergrid%y_max-mothergrid%y_min)/mothergrid%ncells(2)
!    mothergrid%cell_width(3)=(mothergrid%z_max-mothergrid%z_min)/mothergrid%ncells(3)
!    mothergrid%cell_vol=((mothergrid%cell_width(1)/1e14)*(mothergrid%cell_width(2)/1e14)*(mothergrid%cell_width(3)/1e14)) !in 1e42cm^3

    PRINT*,'VOLUME OF GRID CELL (and therefore clump) in e42cm^3',mothergrid%cell_vol
    PRINT*,'GRID CELL WIDTHS in cm: ','X',mothergrid%cell_width(1),'Y',mothergrid%cell_width(2),'Z',mothergrid%cell_width(3)


    !calculate grid cell coords points
    DO ixx=1,mothergrid%ncells(1)
        grid(ixx)=mothergrid%x_min+((ixx-1)*mothergrid%cell_width(1))
        !WRITE(31,*) grid(ixx)
    END DO

    DO iyy=1,mothergrid%ncells(2)
        grid(mothergrid%ncells(1)+iyy)=mothergrid%y_min+((iyy-1)*mothergrid%cell_width(2))
        !WRITE(31,*) grid(mothergrid%ncells(1)+iyy)
    END DO

    DO izz=1,mothergrid%ncells(3)
        grid(mothergrid%ncells(1)+mothergrid%ncells(2)+izz)=mothergrid%z_min+((izz-1)*mothergrid%cell_width(3))
        !WRITE(31,*) grid(mothergrid%ncells(1)+mothergrid%ncells(2)+izz)
    END DO

    !set counters to zero
    iG=0
    SF=0
    !SF2=0
    
    !calculate radius of each cell and scale factors
    DO ixx=1,mothergrid%ncells(1)
        DO iyy=1,mothergrid%ncells(2)
            DO izz=1,mothergrid%ncells(3)
                iG=iG+1
                r(iG)=((grid(ixx)+mothergrid%cell_width(1)/2)**2+(grid(mothergrid%ncells(1)+iyy)+mothergrid%cell_width(2)/2)**2+(grid(mothergrid%ncells(1)+mothergrid%ncells(2)+izz)+mothergrid%cell_width(3)/2)**2)**0.5
            END DO
        END DO
    END DO

    !set counters to zero
    n=0
    iG=0
    h=0.
    SFndust=0.
    ndustav=0.
    micm=0
    mcl=0


    DO ii=1,dust%n_species
        DO jj=1,dust%species(ii)%nsizes
            SFndust=SFndust+(((4*pi*dust%species(ii)%radius(jj,1)**3*dust%species(ii)%rhograin*1e-12)*dust%species(ii)%radius(jj,2)/3))*dust%species(ii)%mweight
        END DO
    END DO

    !calculate dust density at inner radius (rho_in)
    !1.989e-12 = 1.989e33/1e45 (g in Msun / vol e45cm3 -> cm3)
    IF (dust_geometry%rho_power==3) THEN
        rho_in=(dust_geometry%R_min**(-dust_geometry%rho_power))*((dust%mass*1.989e33)/(LOG(dust_geometry%R_max/dust_geometry%R_min)*4*pi))
        rho_in=rho_in*(1.989e-12)
    ELSE
        rho_in=(dust_geometry%R_min**(-dust_geometry%rho_power))*((dust%mass*(3-dust_geometry%rho_power))/(4*pi*(dust_geometry%R_max**(3-dust_geometry%rho_power)-dust_geometry%R_min**(3-dust_geometry%rho_power))))
        rho_in=rho_in*(1.989e-12)
    END IF

    M_icm=dust%mass*(1-dust_geometry%clumped_mass_frac)
    nclumps_tot=dust_geometry%ff*tot_vol/mothergrid%cell_vol
    m_clump=(dust%mass*dust_geometry%clumped_mass_frac)/nclumps_tot

    PRINT*,M_icm,dust%mass,dust_geometry%clumped_mass_frac
    !calculate dust density at inner radius (rho_in) for interclump medium
    IF (dust_geometry%rho_power==3) THEN
        rho_in_icm=dust_geometry%R_min**(-dust_geometry%rho_power)*(1+dust_geometry%ff)*((M_icm)/(LOG(dust_geometry%R_max/dust_geometry%R_min)*4*pi))
        rho_in_icm=rho_in_icm*1.989e-12
    ELSE
        rho_in_icm=dust_geometry%R_min**(-dust_geometry%rho_power)*(1+dust_geometry%ff)*((M_icm)*(3-dust_geometry%rho_power)/(4*pi*(dust_geometry%R_max**(3-dust_geometry%rho_power)-dust_geometry%R_min**(3-dust_geometry%rho_power))))
        rho_in_icm=rho_in_icm*1.989e-12
    END IF

    IF (dust_geometry%clumped_mass_frac==1.0) THEN
        dust_geometry%den_con=0.0
    ELSE
        dust_geometry%den_con=m_clump/(rho_in_icm*5.02765e8*mothergrid%cell_vol)       !5.02765e8=1e42/1.989e33 i.e. conversion factor for  e42cm3 to cm3 and g to Msun
    END IF

    clump_dens=m_clump/(mothergrid%cell_vol*5.02765e8)

    !CALCULATE NUMBER OF PHOTONS EMITTED IN EACH CELL WITHIN RADIAL BOUNDS
    grid_cell(:)%cellStatus=0
    prob=0
    msub=0
    nclumps=0
    h=0

    SF=((dust_geometry%R_max**(1-dust_geometry%clump_power)-dust_geometry%R_min**(1-dust_geometry%clump_power)))/(dust_geometry%R_min**(-dust_geometry%clump_power)*(1-dust_geometry%clump_power))

    IF (dust_geometry%lg_clumped) THEN
        DO WHILE (nclumps<(nclumps_tot))
            iG=0
            !SF2=0
            call RANDOM_NUMBER(cellno)
            iG=ceiling(mothergrid%totcells*cellno)
            IF (iG==0) CYCLE
            IF ((r(iG)<(dust_geometry%R_max_cm)) .AND. (r(iG)>(dust_geometry%R_min_cm))) THEN
                h=h+1
                prob=((dust_geometry%R_min_cm/r(iG))**dust_geometry%clump_power)/SF
                call RANDOM_NUMBER(pp)
                !PRINT*,prob,pp
                IF ((pp<prob) .AND. (grid_cell(iG)%cellStatus/=1)) THEN  !(i.e. if set to be a clump and not already a clump)
                     !CLUMP!
                    
                    grid_cell(iG)%cellStatus=1
                    isG=0
                    nclumps=nclumps+1
                    rhodG=clump_dens
                    mcl=mcl+rhodG*mothergrid%cell_vol*5.02765e8
                    ncl=ncl+1
                    msub=msub+(mothergrid%cell_vol*5.02765e8*rho_in_icm*(dust_geometry%R_min_cm/r(iG))**dust_geometry%clump_power)
                    PRINT*,'clump',ncl,'of',nclumps_tot
                 !ELSE
                 !   SF2=SF2+(dust_geometry%R_min_cm/r(iG))**q
                END IF
            END IF
        END DO

        PRINT*,'average mass density (including clumps) (g/cm3)',(dust%mass_grams*1e-14)/(tot_vol*1e28)
        PRINT*,'icm mass density at inner radius (g/cm3)',rho_in_icm
        PRINT*,'icm mass density at outer radius (g/cm3)',(rho_in_icm)*(dust_geometry%R_min/dust_geometry%R_max)**dust_geometry%rho_power
        PRINT*,'mass of interclump medium (Msun)',M_icm
        PRINT*,'mass in clumps (Msun)',m_clump*nclumps_tot
        PRINT*,'density constrast',dust_geometry%den_con

        iG=0
        h=0
        m=0
        test=0
        DO ixx=1,mothergrid%ncells(1)
            DO iyy=1,mothergrid%ncells(2)
                DO izz=1,mothergrid%ncells(3)
                    iG=iG+1
                    IF ((r(ig)<(dust_geometry%R_max_cm)) .AND. (r(ig)>(dust_geometry%R_min_cm))) THEN
                        h=h+1
                        IF (grid_cell(iG)%cellStatus==0) THEN
                            rhodG=rho_in_icm*(dust_geometry%R_min_cm/r(iG))**dust_geometry%rho_power
                            micm=micm+rhodG*mothergrid%cell_vol*5.02765e8
                            loop=loop+1
                            m=m+rhodG*mothergrid%cell_vol*5.02765e8
                        ELSE
                            rhodG=clump_dens
                            m=m+rhodG*mothergrid%cell_vol*5.02765e8
                            test=test+1
                        END IF
                        ndust=rhodG/SFndust
                        ndustav=ndustav+ndust
                        grid_cell(iG)%axis(:)=(/ grid(ixx),grid(mothergrid%ncells(1)+iyy),grid(mothergrid%ncells(1)+mothergrid%ncells(2)+izz)/)
                        grid_cell(iG)%rho=rhodG
                        grid_cell(iG)%nrho= ndust
                        WRITE(32,*) grid_cell(iG)%axis(:),grid_cell(iG)%rho
                        !!!when looking at clumping need to include ES
                        grid_cell(ig)%id(:)=(/ ixx,iyy,izz /)
                        !this should be equal to numpG not 0 but I've left out the calculation...
                        grid_cell(iG)%numPhots= 0

                    ! at the moment leave out subgrids - not actually sure need them as not full RT
                    !                        IF (mgrid(iG)%cellStatus==1) THEN
                    !                            DO iS=1,3
                    !                                mgrid(iG)%subaxes(iS,1)=mgrid(iG)%axis(iS)
                    !                                mgrid(iG)%subaxes(iS,2)=mgrid(iG)%axis(iS)+width(iS)/2
                    !                            END DO
                    !                            isG=0
                    !                            DO isGx=1,2
                    !                                DO isGy=1,2
                    !                                    DO isGz=1,2
                    !                                        isG=isG+1
                    !                                        mgrid(iG)%subgrid(isG)%axis(1)=mgrid(iG)%axis(1)+((isGx-1)*mothergrid%cell_width(1))/2
                    !                                        mgrid(iG)%subgrid(isG)%axis(2)=mgrid(iG)%axis(2)+((isGy-1)*mothergrid%cell_width(2))/2
                    !                                        mgrid(iG)%subgrid(isG)%axis(3)=mgrid(iG)%axis(3)+((isGz-1)*mothergrid%cell_width(3))/2
                    !                                        mgrid(iG)%subgrid(isG)%rho=rhodG
                    !                                        mgrid(iG)%subgrid(isG)%nrho=ndust
                    !                                    END DO
                    !                                END DO
                    !                            END DO
                    !                        END IF
                        !WRITE(32,*) mgrid(ig)%id(:),mgrid(iG)%numPhots,mgrid(iG)%axis(:),mgrid(iG)%rho,mgrid(iG)%nrho
                    ELSE
                        grid_cell(iG)%axis(:)=(/ grid(ixx),grid(mothergrid%ncells(1)+iyy),grid(mothergrid%ncells(1)+mothergrid%ncells(2)+izz)/)
                        grid_cell(iG)%rho=0.
                        grid_cell(iG)%nrho=0
                        grid_cell(ig)%id(:)=(/ ixx,iyy,izz /)
                        grid_cell(iG)%numPhots= 0
                        !WRITE(32,*) mgrid(ig)%id(:),mgrid(iG)%numPhots,mgrid(iG)%axis(:),mgrid(iG)%rho,mgrid(iG)%nrho
                    END IF
                END DO
            END DO
        END DO

    ELSE
        !not clumping
        h=0
        DO ixx=1,mothergrid%ncells(1)
            DO iyy=1,mothergrid%ncells(2)
                DO izz=1,mothergrid%ncells(3)
                    iG=iG+1
                    IF ((r(ig)<(dust_geometry%R_max_cm)) .AND. (r(ig)>(dust_geometry%R_min_cm))) THEN
                        h=h+1
                        !this was the old incorrect calculation
                        !m=m+((dust%mass_grams*((dust_geometry%R_min_cm)/r(iG))**q)/(SF))/1.989E33
                        !rhodG=((dust%mass_grams*1.0e-14*1e-28*((dust_geometry%R_min_cm)/r(iG))**q)/(SF*mothergrid%cell_vol))
                        !corrected here (virtually no difference...)
                        rhodG=((rho_in)*(dust_geometry%R_min_cm/r(ig))**dust_geometry%rho_power)
                        m=m+rhodG*mothergrid%cell_vol*5.02765e8         !5.02765e8=1e42/1.989e33 i.e. conversion factor for  e42cm3 to cm3 and g to Msun
                        ndust=rhodG/SFndust
                        ndustav=ndustav+ndust
                        grid_cell(iG)%axis(:)=(/ grid(ixx),grid(mothergrid%ncells(1)+iyy),grid(mothergrid%ncells(1)+mothergrid%ncells(2)+izz)/)
                        grid_cell(iG)%rho=rhodG
                        grid_cell(iG)%nrho= ndust
                        !!!ES EDIT
                        !!!watch out for the E19 ES_const in E20

                        grid_cell(iG)%N_e=ES_const*(r(iG)**(-dust_geometry%rho_power))*1E20
                        !PRINT*,ES_const,(r(iG)**(-q)),mgrid(iG)%N_e, r(iG),dust_geometry%R_min_cm
                        grid_cell(ig)%id(:)=(/ ixx,iyy,izz /)
                        !this should be calculates as numpG and not 0, but I've left out the calculation...
                        grid_cell(iG)%numPhots= 0
                        !WRITE(32,*) mgrid(ig)%id(:),mgrid(iG)%numPhots,mgrid(iG)%axis(:),mgrid(iG)%rho,mgrid(iG)%nrho
                    ELSE
                        grid_cell(iG)%axis(:)=(/ grid(ixx),grid(mothergrid%ncells(1)+iyy),grid(mothergrid%ncells(1)+mothergrid%ncells(2)+izz)/)
                        grid_cell(iG)%rho=0.
                        grid_cell(iG)%nrho=0
                        grid_cell(ii)%N_e=0
                        grid_cell(ig)%id(:)=(/ ixx,iyy,izz /)
                        grid_cell(iG)%numPhots= 0
                        !WRITE(32,*) mgrid(ig)%id(:),mgrid(iG)%numPhots,mgrid(iG)%axis(:),mgrid(iG)%rho,mgrid(iG)%nrho
                    END IF
                    WRITE(32,*) grid_cell(iG)%axis(:),grid_cell(iG)%rho
                END DO
            END DO
        END DO
        PRINT*,'DUST GRAIN NUMBER DENSITY AT Rin',rho_in/SFndust
        PRINT*,'DUST GRAIN NUMBER DENSITY AT Rout',((rho_in)*(dust_geometry%R_min_cm/dust_geometry%R_max_cm)**dust_geometry%rho_power)/SFndust
    END IF
    PRINT*,loop
    PRINT*,'this is the actual number of clumps',test


    IF (dust_geometry%lg_clumped) THEN
        PRINT*,'number clumps test:',' using - ',ncl,'requested -',nclumps_tot
        PRINT*,'mass clumps: ','using - ',mcl,'requested: ',m_clump*nclumps_tot
        PRINT*,'mass ICM test:',' using - ',micm,'requested - ',M_icm
        PRINT*,'filling factor',dust_geometry%ff
    ELSE
        PRINT*,'mass check (calculated as rho*V)','using - ',m,'requested -',dust%mass
    END IF
    ndustav=ndustav/h
    PRINT*,'no of grid cells inside SN',h
    PRINT*,'volume of total grid cells inside SN (e42cm)',h*mothergrid%cell_vol
    PRINT*,'average dust grain density per cell (including any clumps)',ndustav
    PRINT*,''




    !CLOSE(31)
    CLOSE(32)

END SUBROUTINE construct_grid

