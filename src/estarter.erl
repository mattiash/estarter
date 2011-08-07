-module(estarter).
-export([reload/0]).

% Returns a list of all modules that were reloaded.
reload() ->
    case os:getenv("APP_ROOT") of
	false -> no_app_root;
	E -> reload(E)
    end.

reload(CodeRoot) ->
    Modules=local_modules(CodeRoot),
%    io:format( "Local modules: ~p~n", [Modules] ),
    reload_if_updated( Modules ).

%% Return a list of all loaded modules that reside in a subdirectory
%% below CodeRoot.
local_modules(CodeRoot) ->
    % AllModules is a list of {Module,BeamFile} where Module is an
    % atom and BeamFile is an absolute filename or an atom for special
    % modules.
    AllModules = code:all_loaded(),
    CodeRootLen = string:len(CodeRoot),
    lists:filter(
      fun({_Module, Beamfile}) ->
	      case is_atom(Beamfile) of
		  true -> false;
		  false ->
		      LString = string:left(Beamfile, CodeRootLen ),
		      string:equal( CodeRoot, LString )
	      end
      end, AllModules ).

% Returns the time when a loaded module was compiled.
compile_time( Module ) ->
    CompileInfo = Module:module_info(compile),
    {Y, M, D, HH, MM, SS} = proplists:get_value(time, CompileInfo, 
						{0, 0, 0, 0,0, 0}),
    {{Y, M, D}, {HH, MM, SS}}.

%% Return the time a file was modified.
file_last_modified_time( File ) ->
    case filelib:last_modified(File) of
        0 ->
	    nosuchfile;
	TS -> 
            [LastMod] = calendar:local_time_to_universal_time_dst(TS),
            LastMod
    end.

reload_if_updated( Modules ) ->
    reload_if_updated( Modules, [] ).

reload_if_updated( [], Acc ) ->
    Acc;

reload_if_updated( [{Module,BeamFile}|Modules], Acc ) ->
    CompileTime = compile_time(Module),
    BeamTime = file_last_modified_time(BeamFile),
    
    CompileSec = calendar:datetime_to_gregorian_seconds( CompileTime ),
    BeamSec = calendar:datetime_to_gregorian_seconds( BeamTime ),
    
    % Fudge the compile time one second to account for files that
    % were compiled one second and the beamfile written the next second.
    case BeamSec > CompileSec + 1 of
        true ->
	    io:format( "Module ~p ~p > ~p~n", 
		       [Module, BeamTime, CompileTime] ),
	    reload_if_updated( Modules, [reload( Module, BeamFile )|Acc] );
	false ->
	    reload_if_updated( Modules, Acc )
    end.

reload( Module, BeamFile ) ->
    case code:soft_purge( Module ) of 
        true ->
	    {module, Module} = code:load_abs(filename:rootname(BeamFile)),
	    [{reload, Module}];
	false ->
            [{purge_fail, Module}]
    end.
