!!! ====================================================================
!!!  Fortran-90-file
!!!     author:          Ethan T. Coon
!!!     filename:        main.F90
!!!     version:
!!!     created:         08 December 2010
!!!       on:            11:48:19 MST
!!!     last modified:   14 September 2011
!!!       at:            16:00:31 PDT
!!!     URL:             http://www.ldeo.columbia.edu/~ecoon/
!!!     email:           ecoon _at_ lanl.gov
!!!
!!! ====================================================================
#define PETSC_USE_FORTRAN_MODULES 1
#include "petsc/finclude/petscsysdef.h"
#include "petsc/finclude/petscvecdef.h"
#include "petsc/finclude/petscdmdef.h"

program MAIN
  use petsc
  use LBM_Options_module
  use LBM_BC_module
  use LBM_Logging_module
  use LBM_module
  implicit none
#include "lbm_definitions.h"

  PetscInt istep
  PetscInt ntimes, npasses
  PetscInt kwrite, kprint
  PetscErrorCode ierr
  character(len=MAXSTRINGLENGTH) infile
  character(len=MAXWORDLENGTH) prefix

  external initialize_bcs
  external initialize_bcs_transport
  external initialize_state
  external initialize_state_transport
  external initialize_walls
  type(lbm_type),pointer:: lbm
  type(options_type),pointer:: options


  ! --- setup environment
  call getarg(1, infile)
  call PetscInitialize(infile, ierr)
  lbm => LBMCreate(PETSC_COMM_WORLD)
  options => lbm%options

  call LoggerCreate()
  call PetscLogStagePush(logger%stage(INIT_STAGE), ierr)

  ! initialize options and constants
  prefix = ''
  call PetscLogEventBegin(logger%event_init_options,ierr)
  call OptionsSetPrefix(options, prefix)
  call OptionsSetUp(options)
  call PetscLogEventEnd(logger%event_init_options,ierr)
  call LBMSetFromOptions(lbm, options, ierr);CHKERRQ(ierr)
  call LBMSetUp(lbm)

  ! set boundary conditions
  call PetscLogEventBegin(logger%event_init_bcsetup,ierr)
  call BCSetValues(lbm%flow%bc, lbm%flow%distribution, options, initialize_bcs)
  if (associated(lbm%transport)) then
     call BCSetValues(lbm%transport%bc, lbm%transport%distribution, &
          options, initialize_bcs_transport)
  end if
  call PetscLogEventEnd(logger%event_init_bcsetup,ierr)

  ! set initial conditions
  call PetscLogEventBegin(logger%event_init_icsetup,ierr)
  if (options%restart) then
     call LBMInitializeStateRestarted(lbm, options%istep, options%kwrite)
     istep = options%istep
  else if (options%ic_from_file) then
     call LBMInitializeStateFromFile(lbm)
     istep = 0
  else
     if (associated(lbm%transport)) then
        call LBMInitializeState(lbm, initialize_state, initialize_state_transport)
     else
        call LBMInitializeState(lbm, initialize_state)
     end if

     if (options%flow_at_steadystate_hasfile) then
        call LBMLoadSteadyStateFlow(lbm, options%flow_at_steadystate_flow_file)
     end if
     istep=0
  endif
  call PetscLogEventEnd(logger%event_init_icsetup,ierr)

  ! start lbm
  if (lbm%grid%info%rank.eq.0) then
     write(*,*) 'calling lbm from inital step', istep, 'to final step', &
          options%ntimes*options%npasses
  end if

  call LBMInit(lbm, istep, options%supress_ic_output)
  call LBMRun(lbm, istep, options%ntimes*options%npasses)
  call PetscLogStagePop(ierr)
  call PetscLogStagePush(logger%stage(DESTROY_STAGE), ierr)
  call LBMDestroy(lbm, ierr)
  call PetscLogStagePop(ierr)
  call LoggerDestroy()
  call PetscFinalize(ierr)
  stop
end program main
  !----------------------------------------------------------

