MODULE initialise

    USE class_line
    USE class_geometry
    USE class_dust
    USE class_grid
    USE class_freq_grid
    USE input


    IMPLICIT NONE






    INTEGER(8)     ::  iP,idP,n,iGP,idPP,n_inactive,freq(1),nsize, &
        & ios,nabs,iDoublet
    INTEGER :: iSh,n_threads
    REAL :: E_0, &
        & SCAT_RF_PT(2),lambda_bin,vel_bin, &
        & tot,shell_width,  &
        & const,dummy
    REAL,DIMENSION(:,:),ALLOCATABLE :: tmp, &
        & grain_rad,Qext,Qsca, &
        & grain_id, &
        & RSh,ab
    INTEGER :: ncl
    REAL,DIMENSION(:),ALLOCATABLE :: grid

    REAL ::SCAT_RF_SN(2), &
        & SCAT_FIN(2),POS_SPH1(3),R_P,ndustav

    INTEGER(8),DIMENSION(:,:),ALLOCATABLE :: ix,iy,iz,NP
    REAL,DIMENSION(:),ALLOCATABLE      :: NP_BIN,diff

    CHARACTER(LEN=1024) :: filename,junk



contains

    SUBROUTINE set_grid_globals()

        !CALCULATE OPACITIES
        CALL calculate_opacities()

        !CONSTRUCT GRID WITH NUMBER OF PHOTONS EMITTED PER CELL
        CALL construct_grid()

        !CALCULATE FREQUENCY OF EMITTED LINE IN Hz
        PRINT*,'minimum velocity',(gas_geometry%R_min/gas_geometry%R_max)*gas_geometry%v_max

        PRINT*,'dust vel index',dust_geometry%v_power
        PRINT*,'gas vel index',gas_geometry%v_power
        PRINT*,'dust density index',dust_geometry%rho_power
        PRINT*,'gas density index',gas_geometry%rho_power
        PRINT*,'Rmax dust',dust_geometry%R_max
        PRINT*,'Rmin dust',dust_geometry%R_min
        PRINT*,'Rmax gas',gas_geometry%R_max
        PRINT*,'Rmin gas',gas_geometry%R_min
        PRINT*,'LAMBDA_0',line%wavelength

                PRINT*,'dust r ratio',dust_geometry%R_ratio
        PRINT*,'gas r ratio',gas_geometry%R_ratio

        !CALCULATE AVERAGE OPTICAL DEPTH FROM Rin to Rout
        PRINT*,'EXTINCTION FOR LAMBDA_0 ',dust%lambda_ext
        PRINT*,'SCATTERING FOR LAMBDA_0',dust%lambda_sca
        PRINT*,'ALBEDO FOR LAMBDA_0',dust%lambda_sca/dust%lambda_ext
        PRINT*,'AVERAGE OPTICAL DEPTH IN LAMBDA_0',ndustav*dust%lambda_ext*(dust_geometry%R_max_cm-dust_geometry%R_min_cm)
        PRINT*,'AVERAGE OPTICAL DEPTH IN V',ndustav*dust%lambda_ext_V*(dust_geometry%R_max_cm-dust_geometry%R_min_cm)
        PRINT*,'AVERAGE NUMBER DENSITY',ndustav

        PRINT*,'EFFECTIVE SPHERICAL RADIUS OF CLUMP (cm)',mothergrid%cell_width(1)*(3.0/(4.0*pi))**0.3333333
        PRINT*,'EFFECTIVE SPHERICAL RADIUS AS A FRACTION OF Rout',(mothergrid%cell_width(1)/dust_geometry%R_max_cm)*(3.0/(4.0*pi))**0.3333333
        PRINT*,'AVERAGE OPTICAL DEPTH OF A CELL IN LAMBDA_0',ndustav*dust%lambda_ext*0.5*mothergrid%cell_width(1)*(3.0/(4.0*pi))**0.3333333
        PRINT*,'AVERAGE OPTICAL DEPTH OF A CELL IN LAMBDA_V',ndustav*dust%lambda_ext_V*0.5*mothergrid%cell_width(1)*(3.0/(4.0*pi))**0.3333333

        call construct_freq_grid()

    END SUBROUTINE


END MODULE
