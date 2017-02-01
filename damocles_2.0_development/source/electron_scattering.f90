MODULE electron_scattering

    use globals
    use class_geometry
    use class_dust
    use class_freq_grid
    use class_grid

    IMPLICIT NONE

    REAL                 ::  ES_const
    REAL                 ::  R_max_ES
    REAL                 ::  lum_q
    REAL                 ::  maxwell_sigma

    REAL, PARAMETER      ::  sigma_T=6.652E-25        !(cm2)
    REAL, PARAMETER      ::  Q_Halpha_5=6.71E-25     !at 5000K
    REAL, PARAMETER      ::  Q_Halpha_10=3.56E-25    !at 10000K
    REAL, PARAMETER      ::  Q_Halpha_20=1.83E-24    !at 20000K

contains

    SUBROUTINE n_e_const()

        IF (ES_temp==5000) THEN
            lum_q=L_Halpha/Q_Halpha_5
        ELSE IF (ES_temp==10000) THEN
            lum_q=L_Halpha/Q_Halpha_10
        ELSE IF (ES_temp==20000) THEN
            lum_q=L_Halpha/Q_Halpha_20
        END IF


        IF (lg_ES) THEN
        IF ((3-2*gas_geometry%rho_power==0) .OR. (1-gas_geometry%rho_power==0)) THEN
            PRINT*,'You have selected a density profile with exponent 1.5 or 1.0 - need an alternative calculation in this case'
            STOP
        END IF
        END IF

        !At some point, include coding for separate line emitting region and gas region
        R_max_ES=gas_geometry%R_max

        maxwell_sigma=((ES_temp*1.51563e7)**0.5)/1000

        IF (gas_geometry%type == "shell") THEN
        ES_const=(lum_q**0.5)*(((3-2*gas_geometry%rho_power)/(4*pi))/(((R_max_ES*1E15)**(3-2*gas_geometry%rho_power)-(gas_geometry%R_min*1E15)**(3-2*gas_geometry%rho_power))))**0.5
        grid_cell%N_e=ES_const*(grid_cell%r**(-dust_geometry%rho_power))*1E20
        ELSE
        PRINT*,'Provision for electron scattering with a non-shell emissivity distribution has not yet been included.'
        END IF

        PRINT*,'av e- density',(ES_const*1E20*((1E15)**(-gas_geometry%rho_power))*((R_max_ES)**(3-gas_geometry%rho_power)-(gas_geometry%R_min)**(3-gas_geometry%rho_power)))/((3-dust_geometry%rho_power)*((R_max_ES)**3-(gas_geometry%R_min)**3))
        PRINT*,''
        PRINT*,'e- optical depth',ES_const*6.6E-5*((1E15*R_max_ES)**(1-gas_geometry%rho_power)-(1E15*gas_geometry%R_min)**(1-gas_geometry%rho_power))/(1-gas_geometry%rho_power)

    END SUBROUTINE

END MODULE
