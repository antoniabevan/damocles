MODULE class_dust

    USE globals
    USE class_line

    implicit none

    TYPE species_obj                        !each species has the following attributes
        INTEGER ::  id                          !id number
        INTEGER ::  nsizes                      !number of grain sizes
        INTEGER ::  n_wav                        !number of wavelengths
        REAL    ::  interval                    !spacing of grain sizes
        REAL    ::  amin,amax                   !amin, amax
        REAL    ::  weight                      !relative weight of species (fractional weighting by area)
        REAL    ::  mweight                     !relative weight of species (fractional weighting by mass)
        REAL    ::  vweight                     !relative weight of species (fraction weighting by volume)
        REAL    ::  power                       !exponent for power law size distribution
        REAL    ::  rhograin                    !density of a dust grain

        CHARACTER(LEN=50)   ::  dataFile        !data file containing optical constants for species
        REAL,ALLOCATABLE    ::  radius(:,:)     !array containing grain sizes (1) and weightings (2)
                                                !weightings are relative abundance by number
        REAL,ALLOCATABLE    ::  mgrain(:)       !mass of grain for each grain size
        REAL,ALLOCATABLE    ::  sca_opacity(:)  !array containing scattering extinctions at each wavelength
        REAL,ALLOCATABLE    ::  ext_opacity(:)  !array containing extinctions at each wavelength
        REAL,ALLOCATABLE    ::  g(:)            !array containing g (asymmetry factor) at each wavelength
        REAL,ALLOCATABLE    ::  wav(:)          !array containing the wavelengths
        REAL,ALLOCATABLE    ::  albedo(:)       !array containing albedos for each wavelength

    END TYPE species_obj

    TYPE dust_obj
        INTEGER                       ::  n_species           !number of species
        REAL                          ::  total_weight        !!to check that total weights of species add to 1
        REAL                          ::  mass                !total mass of dust (M_sun)
        REAL                          ::  mass_grams          !total mass of dust (grams)
        REAL                          ::  lambda_ext(1)       !extinction at rest frame wavelength
        REAL                          ::  lambda_sca(1)       !scattering extinction at rest frame wavelength
        REAL                          ::  lambda_ext_V(1)     !extinction at V band wavelength (547nm)
        REAL                          ::  av_rhograin         !average density of dust grains across all species
        TYPE(species_obj),ALLOCATABLE ::  species(:)
    END TYPE dust_obj

    TYPE(dust_obj) :: dust

contains

    !This subroutine generates grain radii for each independent grain size distribution
    !and relative abundances by number for each grain size
    SUBROUTINE generate_grain_radii()

        !read species file in
        OPEN(21,file = species_file)
        READ(21,*) dust%n_species
        READ(21,*)
        READ(21,*)

        !write to log file
        WRITE(55,*) 'number of species',dust%n_species

        !allocate space for number of different dust species
        ALLOCATE(dust%species(dust%n_species))

        !sum of sepcified species weightings - check sum to 1
        !initialise to 0
        dust%total_weight=0.

        !read in properties for each species (weighting, amin, amax etc.)
        !allocate space for grain size distributions for each species
        !initialise grain sizes in grain size distributions to 0
        DO ii=1,dust%n_species
            READ(21,*) dust%species(ii)%id,dust%species(ii)%dataFile, dust%species(ii)%weight,dust%species(ii)%amin, &
                & dust%species(ii)%amax,dust%species(ii)%power,dust%species(ii)%nsizes

            ALLOCATE(dust%species(ii)%radius(dust%species(ii)%nsizes,2))

            dust%species(ii)%radius=0
            dust%species(ii)%dataFile=trim(dust%species(ii)%dataFile)
            dust%total_weight=dust%total_weight+dust%species(ii)%weight
        END DO

        CLOSE(21)

        !check that the sum of the specified species weightings sums to 1
        IF (dust%total_weight/=1) THEN
            PRINT*, 'WARNING - total species weights do not add to 1'
            PRINT*, 'total weights =',dust%total_weight
        END IF

        !generate grain sizes and relative weights
        DO ii=1,dust%n_species
            !calculate internal between grain radii (linear)
            dust%species(ii)%interval=(dust%species(ii)%amax-dust%species(ii)%amin)/real(dust%species(ii)%nsizes)
            norm=0
            WRITE(55,*) 'area weight',dust%species(ii)%weight

            !!check conversion to weighting by volume
            IF (dust%n_species /= 1) THEN
                PRINT*, 'You have requested more than 1 dust species - please check the volume weighting calculation. Aborting'
                STOP
            END IF
            dust%species(ii)%vweight=(1.0/(1.0+(1.0/dust%species(ii)%weight-1)**(1.5)))
            WRITE(55,*),'volume weight',dust%species(ii)%vweight

            !generate grain radii for grain size distribution
            !calculate sacling factor (norm) to be used to normalise abundances/weightings
            DO jj=1,dust%species(ii)%nsizes
                dust%species(ii)%radius(jj,1)=dust%species(ii)%amin+((jj-1)*dust%species(ii)%interval)
                norm=norm+(dust%species(ii)%radius(jj,1)**dust%species(ii)%power)
            END DO

            !generate weighting (relative abundance by number) for each grain radius (normalised so sum is unity)
            DO jj=1,dust%species(ii)%nsizes
                dust%species(ii)%radius(jj,2)=(dust%species(ii)%radius(jj,1)**dust%species(ii)%power)/norm
            END DO
        END DO


    END SUBROUTINE generate_grain_radii

    !This subroutine calculates the dust extinction efficiences as a function of wavelength
    SUBROUTINE calculate_opacities()

        !optical property variables which will be used for each species
        !not included in species type as do not need to store once Mie calculation performed
        REAL,ALLOCATABLE        :: E_Re(:),E_Im(:)                  !imaginary and real parts of refractive index (n and k values)
        REAL,ALLOCATABLE        :: Qext(:,:),Qsca(:,:),ggsca(:,:)   !exctinction/scattering efficiencies and forward scattering param
        REAL                    :: T_subl                            !sublimation temperature of dust
        REAL                    :: sizeparam                        !standard Mie theory size parameter 2*pi*a/lambda
        COMPLEX                 :: refrel                           !complex version of n and k (n + ik) to be read into Mie routine
        INTEGER                 :: id(1),id_V(1)                    !index in array for rest frame wavelength and visible (547nm)
        CHARACTER(LEN=50)       :: junk                             !holder

        !CALCULATE Qext FOR EACH GRAIN SIZE AND WAVELENGTH

        call generate_grain_radii()

        !write out to log file
        DO ii=1,dust%n_species
            WRITE(55,*) 'min grain radius',dust%species(1)%amin
            WRITE(55,*) 'max grain radius',dust%species(1)%amax
            WRITE(55,*) 'power law index for grain distriution',dust%species(1)%power
        END DO


        !!check from here down
        dust%av_rhograin=0

        !read in optical data (n and k values) for each species
        DO ii=1,dust%n_species
            OPEN(13,file=PREFIX//"/share/damocles/"//trim(dust%species(ii)%dataFile))
            READ(13,*) dust%species(ii)%n_wav
            READ(13,*)
            READ(13,*) junk,T_subl,dust%species(ii)%rhograin

            !allocate (temporary) space for storing optical properties for Mie calculation
            !results will be stored but not optical properties
            !space reallocated for each species
            ALLOCATE(dust%species(ii)%wav(dust%species(ii)%n_wav))
            ALLOCATE(E_Re(dust%species(ii)%n_wav))
            ALLOCATE(E_Im(dust%species(ii)%n_wav))

            !read in optical data for each species file
            DO jj=1,dust%species(ii)%n_wav
                READ(13,*) dust%species(ii)%wav(jj),E_Re(jj),E_Im(jj)
            END DO
            !calculate average grain density across all species
            dust%av_rhograin=dust%av_rhograin+dust%species(ii)%vweight*dust%species(ii)%rhograin

            CLOSE(13)

            !av_csa=0

            ALLOCATE(dust%species(ii)%mgrain(dust%species(ii)%nsizes))

            DO jj=1,dust%species(ii)%nsizes
                dust%species(ii)%mgrain(jj)=(4*pi*dust%species(ii)%radius(jj,1)**3*dust%species(ii)%rhograin*1e-12)/3                !in grams
                !av_csa=av_csa+(dust%species(ii)%radius(jj,2)*pi*(dust%species(ii)%radius(jj,1)*1e-4)**2)
            END DO


            ALLOCATE(Qext(dust%species(ii)%nsizes,dust%species(ii)%n_wav))
            ALLOCATE(Qsca(dust%species(ii)%nsizes,dust%species(ii)%n_wav))
            ALLOCATE(ggsca(dust%species(ii)%nsizes,dust%species(ii)%n_wav))
            ALLOCATE(dust%species(ii)%ext_opacity(dust%species(ii)%n_wav))
            ALLOCATE(dust%species(ii)%sca_opacity(dust%species(ii)%n_wav))
            ALLOCATE(dust%species(ii)%albedo(dust%species(ii)%n_wav))
            ALLOCATE(dust%species(ii)%g(dust%species(ii)%n_wav))

            dust%species(ii)%ext_opacity(:)=0.
            dust%species(ii)%sca_opacity(:)=0.
            dust%species(ii)%g(:)=0.
            OPEN(unit=24,file='output/opacity_wav.out')
            WRITE(24,*) 'species no - wav - extinction - scatter - g'
            !OPEN(unit=57,file='output/opacity_size.out')
            !WRITE(57,*) 'species no - wav - size - Qext - Qsca'
            OPEN(57,file='output/opacity_size.out')

            DO jj=1,dust%species(ii)%n_wav
                !alb=0
                !              PRINT*,j,dust%species(i)%wav(j)
                DO kk=1,dust%species(ii)%nsizes
                    !PRINT*,dust%species(i)%radius(k,1),dust%species(i)%radius(k,2)
                    sizeparam=2*pi*dust%species(ii)%radius(kk,1)/(dust%species(ii)%wav(jj))

                    refrel=cmplx(E_Re(jj),E_Im(jj))

                    call BHmie(sizeparam,refrel,Qext(kk,jj),Qsca(kk,jj),ggsca(kk,jj))
                    !PRINT*,Qext(k,j),Qsca(k,j),dust%species(i)%wav(j),dust%species(i)%radius(k,1)
                    !alb=alb+(dust%species(ii)%radius(kk,2)*(Qsca(kk,jj)/Qext(kk,jj))*pi*(dust%species(ii)%radius(kk,1)*1e-4)**2)
                    dust%species(ii)%ext_opacity(jj)=dust%species(ii)%ext_opacity(jj)+(dust%species(ii)%radius(kk,2)*Qext(kk,jj)*pi*(dust%species(ii)%radius(kk,1)*1e-4)**2)                !NOTE here that grain_rad(j,2) is the relative abundance of grain with radius a
                    dust%species(ii)%sca_opacity(jj)=dust%species(ii)%sca_opacity(jj)+(dust%species(ii)%radius(kk,2)*Qsca(kk,jj)*pi*(dust%species(ii)%radius(kk,1)*1e-4)**2)
                    dust%species(ii)%g(jj)=dust%species(ii)%g(jj)+(dust%species(ii)%radius(kk,2)*ggsca(kk,jj)*pi*(dust%species(ii)%radius(kk,1)*1e-4)**2)

                END DO

                dust%species(ii)%albedo(jj)=dust%species(ii)%sca_opacity(jj)/dust%species(ii)%ext_opacity(jj)

                !PRINT*,j,dust%species(i)%wav(j)

            END DO

            CLOSE(24)
            CLOSE(57)
            DEALLOCATE(E_Re)
            DEALLOCATE(E_Im)
            DEALLOCATE(dust%species(ii)%mgrain)
            DEALLOCATE(Qext)
            DEALLOCATE(Qsca)
            DEALLOCATE(ggsca)

        END DO


        !calculate average opacity for lamba_0
        dust%lambda_ext=0
        dust%lambda_ext_V=0
        DO jj=1,dust%n_species

            dust%species(jj)%mweight=dust%species(jj)%rhograin*dust%species(jj)%vweight/dust%av_rhograin
            PRINT*,dust%species(jj)%rhograin
            PRINT*,'mass weight',dust%species(jj)%mweight
            !find neareset wavelength to lambda_0

            id=MINLOC(ABS((dust%species(jj)%wav(:)-(line%wavelength/1000))))
            id_V=MINLOC(ABS((dust%species(jj)%wav(:)-(547.0/1000))))
            PRINT*,'id check',id,id_V
            PRINT*,'For species no',jj,'albedo',dust%species(jj)%sca_opacity(id)/dust%species(jj)%ext_opacity(id),'weight',dust%species(jj)%weight
            !calculate extinction for lambda_0 weighted sum over all species
            dust%lambda_ext=dust%lambda_ext+dust%species(jj)%weight*(dust%species(jj)%ext_opacity(id)-((dust%species(jj)%ext_opacity(id)-dust%species(jj)%ext_opacity(id-1))* &
                & ((dust%species(jj)%wav(id)-(line%wavelength/1000))/(dust%species(jj)%wav(id)-dust%species(jj)%wav(id-1)))))
            dust%lambda_sca=dust%lambda_sca+dust%species(jj)%weight*(dust%species(jj)%sca_opacity(id)-((dust%species(jj)%sca_opacity(id)-dust%species(jj)%sca_opacity(id-1))* &
                & ((dust%species(jj)%wav(id)-(line%wavelength/1000))/(dust%species(jj)%wav(id)-dust%species(jj)%wav(id-1)))))

            dust%lambda_ext_V=dust%lambda_ext_V+dust%species(jj)%weight*(dust%species(jj)%ext_opacity(id_V)-((dust%species(jj)%ext_opacity(id_V)-dust%species(jj)%ext_opacity(id_V-1))* &
                & ((dust%species(jj)%wav(id_V)-(547.0/1000))/(dust%species(jj)%wav(id_V)-dust%species(jj)%wav(id_V-1)))))

        END DO
    END SUBROUTINE calculate_opacities


END MODULE class_dust
