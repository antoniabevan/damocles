MODULE driver

    USE globals
    USE class_line
    USE class_freq_grid
    USE class_grid
    USE input
    USE initialise

    USE vector_functions
    USE init_packet
    USE model_comparison

    IMPLICIT NONE

    INTEGER,EXTERNAL ::  omp_get_num_threads, omp_get_thread_num
    INTEGER ::  lgabs,lgactive,idP_thread
    INTEGER ::  celliD,iG,iG_axis(3),freqid,los


    REAL    ::  nu_p,theta,w,w_abs
    REAL    ::  dir_cart(3),pos_cart(3)
    INTEGER ::  scatno
    INTEGER ::  NP_clump

contains


    SUBROUTINE run_code()
        implicit none
        
        REAL  :: chi2

        !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!INITIALIZE PHOTON EMISSION!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!


        !READ INPUTS AND CONSTRUCT GRID
        call read_input()
        PRINT*, 'input read, calculating opacities...'

        !lambda_0 is active initial wavelength
        line%wavelength=line%doublet_wavelength_1
        line%frequency=c*10**9/line%wavelength
        
        w_abs=0
        DO iDoublet=1,2

            IF ((.not. lg_doublet) .and. (iDoublet==2))  THEN
                EXIT
            ELSE
                IF (iDoublet==2) THEN
                    !active wavelength is now second element of doublet
                    line%wavelength=line%doublet_wavelength_2
                    line%frequency=c*10**9/line%wavelength
                    PRINT*,'NUCHECK',line%frequency
                END IF


                IF (iDoublet==1) THEN
                    !Construct grid
                    call build_dust_grid()
                    call build_emissivity_dist()
                    call set_grid_globals()



                    PRINT*, 'Opacities calculated, constructing grid and frequency array...'

                    PRINT*, 'grid constructed.'
                    !OPEN ENERGY OUTPUT FILE
                    !OPEN(13,file=trim(filename))
                    OPEN(15,file='output/output.out')

                END IF

                PRINT*,"iDoublet",iDoublet
                PRINT*,"wavelength",line%wavelength

                !SET COUNTERS EQUAL TO 0
                idP=0
                IF (iDoublet==1) THEN
                    n=0
                    n_inactive=0
                    nabs=0
                END IF

                !!freqid(:,:)=1
                !w_abs=0

                tot=0
                !!los(:,:)=0.

                !GENERATE RANDOM SEED AND MATRIX
                PRINT*, 'generating random seed...'
                CALL init_random_seed
                !PRINT*, 'generating random number matrix...'


                PRINT*, 'starting iteration...'
                !CALCULATE NO PACKETS IN SHELL,
                !POSITION OF PACKETS AND DOPPLER SHIFTED FREQUENCY.
                !TRACE PHOTONS THROUGH GRID.
                !!!!!!!!!!!!!!!!!!!!!!!!

                IF (iDoublet==1) THEN
                    shell_width=(gas_geometry%R_max-gas_geometry%R_min)/n_shells!Calculate width of shells
                    PRINT*,'****************SHELL WIDTH****************',shell_width
                    !const=n_packets*(0*q-1)/(dust_geometry%R_min**(1-0*q)-dust_geometry%R_max**(1-0*q))
                    !const=n_packets*(2*q-1)/(dust_geometry%R_min**(1-2*q)-dust_geometry%R_max**(1-2*q))

                    !scale factor to work out number of packets in each shell

                    IF ((gas_geometry%emis_power*gas_geometry%rho_power)==3) THEN
                        const=n_packets/(LOG(gas_geometry%R_max/gas_geometry%R_min))
                    ELSE
                        const=n_packets*(gas_geometry%emis_power*gas_geometry%rho_power-3)/(gas_geometry%R_min**(3-gas_geometry%emis_power*gas_geometry%rho_power)-gas_geometry%R_max**(3-gas_geometry%emis_power*gas_geometry%rho_power))
                    END IF

                    PRINT*,'CONST',const
                    RSh(1,1)=gas_geometry%R_min
                    RSh(1,2)=gas_geometry%R_min+shell_width
                END IF

                IF (iDoublet==1) THEN
                    NP_BIN=0
                    w_abs=0
                    nabs=0
                END IF
                idP=0
                
                ii=0
                IF (gas_geometry%clumped_mass_frac==1) THEN
                NP(:,1)=0
                   DO iSh=1,mothergrid%totcells
                        IF (grid_cell(iSh)%cellStatus==1) THEN
                           ii=ii+1
                           PRINT*,'clump number',ii,'of',ncl
                            
                            
                            NP(iSh,1)=n_packets/ncl
                            n=n+NP(iSh,1)
                            
                            celliD=iSh
                            call run_packets(celliD)
                        END IF

                    END DO

                ELSE
                DO iSh=1,n_shells
                   
                !divide the SN up into radial shells
                     !NP(iSh,1)=NINT(const*(RSh(iSh,1)**(1-0*q)-RSh(iSh,2)**(1-0*q))/(0*q-1))
                     !NP(iSh,1)=NINT(const*(RSh(iSh,1)**(1-2*q)-RSh(iSh,2)**(1-2*q))/(2*q-1))!calculate number of packets to be released in shell i
                   PRINT*,'shell no',iSh,'of',n_shells
                    IF (iDoublet==1) THEN
                        IF ((gas_geometry%emis_power*gas_geometry%rho_power)==3) THEN
                            NP(iSh,1)=NINT(const*LOG(RSh(iSh,2)/RSh(iSh,1)))
                        ELSE
                            NP(iSh,1)=NINT(const*(RSh(iSh,1)**(3-gas_geometry%emis_power*gas_geometry%rho_power)-RSh(iSh,2)**(3-gas_geometry%emis_power*gas_geometry%rho_power))/(gas_geometry%emis_power*gas_geometry%rho_power-3))
                        END IF
                        
                    END IF
                    n=n+NP(iSh,1)
                    iG=0 !to be calculated by emit_photon routine in run_packets (see below)
                   
                    call run_packets(iG)

                    RSh(iSh+1,1:2)=(/ RSh(iSh,2),RSh(iSh,2)+shell_width /)  !calculate upper and lower radius bound for each shell

                END DO
                END IF
            END IF
        END DO
        !!!!!!!!!!!!!!!!!!!!!!!!

        IF (lg_doublet) THEN
           PRINT*,line%luminosity,n,n_inactive,2.0*n-n_inactive
            E_0=line%luminosity/real(2.0*n-n_inactive)!Energy of a single packet in W/um (note uses actual number of active photons)
        
         ELSE
            E_0=line%luminosity/real(n-n_inactive)
        END IF

        PRINT*,E_0,'E0'

        PRINT*,''
        PRINT*,'**********************'
        PRINT*,'All percentages out of total number of active packets:'
        PRINT*,''
        PRINT*,'TOTAL NUMBER OF PACKETS',n
        PRINT*,'NUMBER OF ACTIVE(PROPAGATED) PACKETS',n-n_inactive
        !WRITE OUT ENERGY FILE - wavelength, velocity, energy (W/um)
        DO ii=1,nu_grid%n_bins-1
                lambda_bin=(c*10**9)*(0.5/nu_grid%bin(ii,1)+0.5/nu_grid%bin(ii+1,1))
                IF (.not. lg_doublet) THEN
                    vel_bin=(c*1e-3*(lambda_bin**2-line%wavelength**2)/(line%wavelength**2+lambda_bin**2))
                    !WRITE(13,*) lambda_bin,vel_bin,E_0*NP_BIN(inu)
                    WRITE(15,*) lambda_bin,vel_bin,E_0*NP_BIN(ii)    !duplicate file for plotting
                ELSE
                    !WRITE(13,*) lambda_bin,E_0*NP_BIN(ii)
                   
                   WRITE(15,*) lambda_bin,E_0*NP_BIN(ii)    !duplicate file for plotting
                END IF
        END DO

        PRINT*,'*******************'
        PRINT*,'absorbed weight',w_abs
        IF (lg_doublet) THEN
           PRINT*,'undepleted luminosity (in units e40 erg/s)',line%luminosity/(1-w_abs/real(n-n_inactive))
        ELSE
           PRINT*,'undepleted luminosity (in units e40 erg/s)',line%luminosity/(1-w_abs/real(n-n_inactive))
        END IF
        !CLOSE(13)
        CLOSE(15)
        !CLOSE(17)
        IF (.not. lg_doublet) THEN

        PRINT*,'NUMBER OF INACTIVE PACKETS',n_inactive
        PRINT*,'NUMBER OF ABSORBED PACKETS',nabs,real(nabs)*100/real(n-n_inactive),'%'
        PRINT*,'ABSORBED WEIGHT PERCENTAGE',w_abs*100/real(n-n_inactive),'%'
        PRINT*,''
        PRINT*,'TOTAL ENERGY',line%luminosity
        PRINT*,'ENERGY PER PACKET (ACTIVE ONLY)',E_0
        PRINT*,'TOTAL ENERGY ABSORBED',nabs*E_0
        PRINT*,''
        PRINT*,'FRACTION OF ESCAPED PACKETS IN LINE OF SIGHT',tot,real(tot)*100/real((n-n_inactive-nabs)),'%'
        PRINT*,''
        PRINT*,'DUST MASS',dust%mass
        PRINT*,'OUTPUT FILENAME:  ', trim(filename)
        PRINT*,''
        PRINT*,'FINISHED MODELLING!'
        PRINT*,''
        PRINT*,'Calculating chi...'
        PRINT*,''
        
     ELSE

        PRINT*,'DUST MASS',dust%mass
        PRINT*,nabs,n,n_inactive
        PRINT*,'percentage of absorbed packets',real(nabs*100.0)/real(n-n_inactive)
        PRINT*,'absorbed weight',w_abs*100/real(n-n_inactive)
     PRINT*,'FINISHED MODELLING!'   
     END IF


        call linear_interp(chi2)

        DEALLOCATE(grid_cell)
        DEALLOCATE(nu_grid%bin)
        DEALLOCATE(tmp)
        DEALLOCATE(grid)
        DEALLOCATE(np)
        DEALLOCATE(np_bin)
        DEALLOCATE(RSh)
        DEALLOCATE(dust%species)
    END SUBROUTINE run_code

    SUBROUTINE run_packets(celliD)
      INTEGER::celliD

!!!!!OPENMP HAS NOT BEEN UPDATED AFTER RECENT AMENDMENTS SO DO NOT EMPLOY WITHOUT THOROUGH CHECKING FIRST!!!!!!!!!!!
!!$OMP PARALLEL DEFAULT(PRIVATE) SHARED(dust_geometry%ff,gas_geometry%rho_power,line%doublet_ratio,iDoublet,tot,n_inactive,nabs,shell_width,width,NP_BIN,NP,iSh,RSh,dust_geometry%R_min,dust_geometry%R_max,gas_geometry%R_min,gas_geometry%R_max,idP,lg_LOS,lg_ES,grid,mothergrid%ncells,nu_grid%bin,dust_geometry%v_max,gas_geometry%v_max,l,gas_geometry%v_power,dummy,mgrid,dust,lg_vel_shift)

                    !PRINT*,'num of threads', omp_get_num_threads()

                    idP_thread=0

                    
                    !!$OMP DO SCHEDULE(dynamic)
                    DO iP=1,NP(iSh,1)
                        !PRINT*,'thread number',omp_get_thread_num()
                       
                        call emit_photon(nu_p,dir_cart,pos_cart,iG_axis,lgactive,w,celliD)
                        
                        !PRINT*,'thread no',omp_get_thread_num()
                        IF (lgactive == 1) THEN
                            scatno=0
                            lgabs=0
                    
                            call propagate(nu_p,dir_cart,pos_cart*1e15,iG_axis,iG,lgabs,lgactive,w,scatno)
                    
                            theta=acos(pos_cart(3)/((pos_cart(1)**2+pos_cart(2)**2+pos_cart(3)**2)**0.5))
                            IF (lgabs == 1) THEN
                                !!$OMP CRITICAL
                                nabs=nabs+1
                                IF (iDoublet==2) THEN
                                   w_abs=w_abs+w/line%doublet_ratio
                                ELSE
                                   w_abs=w_abs+w
                                END IF
                                !!$OMP END CRITICAL
                            END IF


                            
                            ! IF PHOTON IN LINE OF SIGHT THEN CALCULATE WHICH FREQ BIN PACKET IN AND ADD 1 TO TOTAL IN FREQ BIN
                            IF (.not. lg_LOS) THEN
                                IF (lgabs == 0) THEN
                                   
                                   los=1.
                                    tmp(:,1)=(nu_p-nu_grid%bin(:,1))                         !Calculate distance to each freq point
                                    freq=MINLOC(tmp,1,tmp>0)                                !Find the smallest distance and thus nearest freq point
                                    freqid=freq(1)                              !Attach id of freq bin to photon id
                                    IF (freqid==0) THEN
                                        PRINT*,'photon outside frequency range',freqid,nu_p,w
                                        PRINT*,nu_grid%fmin,nu_grid%fmax
                                    ELSE
                                        IF (iDoublet==2) THEN
                                            w=w/line%doublet_ratio
                                        
                                        END IF
                                         !!$OMP CRITICAL
                                        dummy=NP_BIN(freqid)+w                  !Add 1 to number of photons in that freq bin

                                        NP_BIN(freqid)=dummy

                                        tot=tot+1
                                         !!$OMP END CRITICAL
                                    END IF
                                END IF
                            ELSE
                                IF ((theta<(pi/6)) .AND. (lgabs==0)) THEN                       !Only calculate freq bin for those in LoS
                                    !Packets which are not absorbed
                                    los=1.
                                    tmp(:,1)=(nu_p-nu_grid%bin(:,1))                     !Calculate distance to each freq point
                                    freq=MINLOC(tmp,1,tmp>0)                            !Find the smallest distance and thus nearest freq point
                                    freqid=freq(1)                          !Attach id of freq bin to photon id
                                    IF (freqid==0) THEN
                                        PRINT*,'photon outside frequency range',freqid,nu_p,w
                                    ELSE
                                         !!$OMP CRITICAL
                                        IF (lg_doublet) THEN
                                            IF (iDoublet==2) THEN
                                                w=w/line%doublet_ratio
                                        
                                            END IF
                                        END IF
                                        dummy=NP_BIN(freqid)+w                  !Add 1 to number of photons in that freq bin
                                        !PRINT*,w
                                        tot=tot+1
                                         !!$OMP END CRITICAL
                                    END IF
                                END IF
                            END IF
                        END IF
!                        PRINT*,'threadno',omp_get_thread_num()
                     END DO
                    
                     !!$OMP END DO

                     !!$OMP CRITICAL
                    idP=idP+idP_thread
                     !!$OMP END CRITICAL
                    
                     !!$OMP END PARALLEL

                    !close log file (opened in read_input)
                    CLOSE(55)
    END SUBROUTINE

END MODULE driver
