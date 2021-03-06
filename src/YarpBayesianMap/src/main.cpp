#include <yarp/os/all.h>
#include <yarp/dev/all.h>
#include <iostream>
#include "BayesianModule.h"

using namespace yarp::os;
using namespace yarp::dev;


int main(int argc, char * argv[])
{
    /* initialize yarp network */
    Network yarp;

    ResourceFinder rf;
    rf.configure(argc, argv);
    rf.setVerbose(true);
    std::cout << "[INFO] Configuring and starting module. \n";

    if (!yarp.checkNetwork(1))
    {
        printf("[ERROR] YARP server not available!\n");
        return -1;
    }

    BayesianModule module;
    return module.runModule(rf);
}
