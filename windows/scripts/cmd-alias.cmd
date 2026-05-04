@echo off
doskey ll=dir /w
doskey grep=findstr $*
doskey ls=dir $*
doskey omd=npx defuddle parse