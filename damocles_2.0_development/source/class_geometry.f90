MODULE class_geometry

    IMPLICIT NONE

    TYPE geometry_obj

        REAL        ::  clumped_mass_frac   !mass fraction of dust located in clumpes. 0 indicates no clumping.
        REAL        ::  R_ratio             !ratio between inner and outer radii (R_in/R_out)
        REAL        ::  v_max               !maximum velocity (km/s) at R_out
        REAL        ::  v_power             !value of l where velocity profile is v~r^l
        REAL        ::  rho_power           !value of q where density profile is rho~r^-q
        REAL        ::  emis_power          !value of b where emissivity~r^-qb
        REAL        ::  clump_power         !value of q where the number density of clumps is distributed as n~r^-q
        REAL        ::  ff                  !filling factor of clumps by volume
        REAL        ::  den_con             !density contrast at inner radius
        REAL        ::  R_min,R_max         !inner and outer radii of distribution (e15cm)
        REAL        ::  R_min_cm,R_max_cm   !inner and outer radii of distribution (cm)

        LOGICAL     ::  lg_clumped          !is the medium clumped?

        CHARACTER(LEN=9) ::   type

    END TYPE


    TYPE(geometry_obj) gas_geometry, dust_geometry

    contains

    SUBROUTINE check_dust_clumped()
        !test 0 or 1 entered
        IF (dust_geometry%clumped_mass_frac < 0 .OR. dust_geometry%clumped_mass_frac > 1) THEN
            PRINT*, "Aborted - please enter a value between 0 and 1 for the mass fraction of dust in clumps."
            STOP
        END IF
        dust_geometry%lg_clumped = .false.
        IF (dust_geometry%clumped_mass_frac > 0) dust_geometry%lg_clumped = .true.
    END SUBROUTINE

END MODULE class_geometry
