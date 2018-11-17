#define __instances_macuser 1
#define __instances_macuser1 1
#define __instances_llc 1
#define __instances_applicant 1
#define __instances_applicant2 1
#define __instances_registrar 1
#define __instances_leaveallpro 1

/*
 * PROMELA Validation Model
 * GARP(main)
 */

#include "defines"
#include "macuser"
#include "macuser1"
#include "llc"
#include "applicant"
#include "applicant2"
#include "registrar"
#include "leaveall"

init
{	atomic {
	  run macuser(0); run macuser1(1);
	  run llc();
	  run applicant(0); run applicant2(1);
	  run registrar(0);
	  run leaveallpro(0)
	}
}
