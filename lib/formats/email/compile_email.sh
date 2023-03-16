#!/bin/bash

flowcpp lingo/pegcode/pegcompiler.flow -- file=domain.lingo out=domain_pegop.flow && 
flowcpp lingo/pegcode/pegcompiler.flow -- file=email.lingo out=email_pegop.flow