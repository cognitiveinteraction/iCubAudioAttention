# Copyright: (C) 2016 Rbcs
# Authors:  Francesco Rea
# CopyPolicy: Released under the terms of the GNU GPL v2.0.

set(appname bayesianMapApp)
#icub_app(${appname})

file(GLOB conf ${CMAKE_CURRENT_SOURCE_DIR}/conf/*.ini ${CMAKE_CURRENT_SOURCE_DIR}/conf/*.xml)
file(GLOB scripts ${CMAKE_CURRENT_SOURCE_DIR}/scripts/*.template ${CMAKE_CURRENT_SOURCE_DIR}/scripts/*.sh )

# Introduced the file *.sh in the installation
# Removed the installation in $ICUB_ROOT/app 11/10/13

#icub_app_install(${appname} 
#                 FILES ${conf}
#                 DESTINATION conf)

#icub_app_install(${appname} 
#                FILES ${scripts}
#                DESTINATION scripts)

yarp_install(FILES ${conf} DESTINATION ${ICUBCONTRIB_CONTEXTS_INSTALL_DIR}/${appname})

yarp_install(FILES ${scripts} DESTINATION ${ICUBCONTRIB_APPLICATIONS_TEMPLATES_INSTALL_DIR})
