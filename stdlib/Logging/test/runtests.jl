using Logging

import Logging: min_enabled_level, shouldlog, handle_message

@noinline func1() = backtrace()

@testset "Logging" begin

@testset "ConsoleLogger" begin
    # First pass log limiting
    @test min_enabled_level(ConsoleLogger(DevNull, Logging.Debug)) == Logging.Debug
    @test min_enabled_level(ConsoleLogger(DevNull, Logging.Error)) == Logging.Error

    # Second pass log limiting
    logger = ConsoleLogger(DevNull)
    @test shouldlog(logger, Logging.Info, Base, :group, :asdf) === true
    handle_message(logger, Logging.Info, "msg", Base, :group, :asdf, "somefile", 1, maxlog=2)
    @test shouldlog(logger, Logging.Info, Base, :group, :asdf) === true
    handle_message(logger, Logging.Info, "msg", Base, :group, :asdf, "somefile", 1, maxlog=2)
    @test shouldlog(logger, Logging.Info, Base, :group, :asdf) === false

    # Log formatting
    function genmsg(level, message, _module, filepath, line; color=false, min_level_prefix=Logging.Warn, show_limited=true, kws...)
        buf = IOBuffer()
        io = IOContext(buf, :displaysize=>(30,75), :color=>color)
        logger = ConsoleLogger(io, Logging.Debug,
                               min_level_prefix=min_level_prefix,
                               show_limited=show_limited)
        Logging.handle_message(logger, level, message, _module, :group, :id,
                               filepath, line; kws...)
        s = String(take!(buf))
    end

    @test genmsg(Logging.Debug, "msg", Main, "some/path.jl", 101) ==
    """
    [ msg                                              Debug @ Main path.jl:101
    """
    @test genmsg(Logging.Info, "msg", Main, "some/path.jl", 101) ==
    """
    [ msg                                               Info @ Main path.jl:101
    """
    @test genmsg(Logging.Warn, "msg", Main, "some/path.jl", 101) ==
    """
    [ Warning: msg                                   Warning @ Main path.jl:101
    """
    @test genmsg(Logging.Error, "msg", Main, "some/path.jl", 101) ==
    """
    [ Error: msg                                       Error @ Main path.jl:101
    """

    # Disabling / enabling the level prefix
    @test genmsg(Logging.Debug, "msg", Main, "some/path.jl", 101, min_level_prefix=Logging.BelowMinLevel) ==
    """
    [ Debug: msg                                       Debug @ Main path.jl:101
    """
    @test genmsg(Logging.Error, "msg", Main, "some/path.jl", 101, min_level_prefix=Logging.AboveMaxLevel) ==
    """
    [ msg                                              Error @ Main path.jl:101
    """

    # Long line
    @test genmsg(Logging.Error, "msg msg msg msg msg msg msg msg msg msg msg msg msg", Main, "some/path.jl", 101) ==
    """
    ┌ Error: msg msg msg msg msg msg msg msg msg msg msg msg msg
    └                                                  Error @ Main path.jl:101
    """

    # Multiline messages
    @test genmsg(Logging.Warn, "line1\nline2", Main, "some/path.jl", 101) ==
    """
    ┌ Warning: line1
    │ line2
    └                                                Warning @ Main path.jl:101
    """

    # Keywords
    @test genmsg(Logging.Error, "msg", Base, "other.jl", 101, a=1, b="asdf") ==
    """
    ┌ Error: msg
    │   a = 1
    │   b = "asdf"
    └                                                 Error @ Base other.jl:101
    """
    # Exceptions use showerror
    @test genmsg(Logging.Info, "msg", Base, "other.jl", 101, exception=DivideError()) ==
    """
    ┌ msg
    │   exception = DivideError: integer division error
    └                                                  Info @ Base other.jl:101
    """
    # Attaching backtraces
    bt = func1()
    @test startswith(genmsg(Logging.Info, "msg", Base, "other.jl", 101,
                            exception=(DivideError(),bt)),
    """
    ┌ msg
    │   exception =
    │    DivideError: integer division error
    │    Stacktrace:
    │     [1] func1() at""")


    # Keywords - limiting the amount which is printed
    @test genmsg(Logging.Info, "msg", Main, "some/path.jl", 101,
                 a=fill(1.00001, 100,100), b=fill(2.00002, 10,10)) ==
    """
    ┌ msg
    │   a =
    │    100×100 Array{Float64,2}:
    │     1.00001  1.00001  1.00001  1.00001  …  1.00001  1.00001  1.00001
    │     1.00001  1.00001  1.00001  1.00001     1.00001  1.00001  1.00001
    │     1.00001  1.00001  1.00001  1.00001     1.00001  1.00001  1.00001
    │     ⋮                                   ⋱                           
    │     1.00001  1.00001  1.00001  1.00001     1.00001  1.00001  1.00001
    │     1.00001  1.00001  1.00001  1.00001     1.00001  1.00001  1.00001
    │     1.00001  1.00001  1.00001  1.00001     1.00001  1.00001  1.00001
    │   b =
    │    10×10 Array{Float64,2}:
    │     2.00002  2.00002  2.00002  2.00002  …  2.00002  2.00002  2.00002
    │     2.00002  2.00002  2.00002  2.00002     2.00002  2.00002  2.00002
    │     2.00002  2.00002  2.00002  2.00002     2.00002  2.00002  2.00002
    │     ⋮                                   ⋱                           
    │     2.00002  2.00002  2.00002  2.00002     2.00002  2.00002  2.00002
    │     2.00002  2.00002  2.00002  2.00002     2.00002  2.00002  2.00002
    │     2.00002  2.00002  2.00002  2.00002     2.00002  2.00002  2.00002
    └                                                   Info @ Main path.jl:101
    """
    # Limiting the amount which is printed
    @test genmsg(Logging.Info, "msg", Main, "some/path.jl", 101,
                 a=fill(1.00001, 10,10), show_limited=false) ==
    """
    ┌ msg
    │   a =
    │    10×10 Array{Float64,2}:
    │     1.00001  1.00001  1.00001  1.00001  1.00001  1.00001  1.00001  1.00001  1.00001  1.00001
    │     1.00001  1.00001  1.00001  1.00001  1.00001  1.00001  1.00001  1.00001  1.00001  1.00001
    │     1.00001  1.00001  1.00001  1.00001  1.00001  1.00001  1.00001  1.00001  1.00001  1.00001
    │     1.00001  1.00001  1.00001  1.00001  1.00001  1.00001  1.00001  1.00001  1.00001  1.00001
    │     1.00001  1.00001  1.00001  1.00001  1.00001  1.00001  1.00001  1.00001  1.00001  1.00001
    │     1.00001  1.00001  1.00001  1.00001  1.00001  1.00001  1.00001  1.00001  1.00001  1.00001
    │     1.00001  1.00001  1.00001  1.00001  1.00001  1.00001  1.00001  1.00001  1.00001  1.00001
    │     1.00001  1.00001  1.00001  1.00001  1.00001  1.00001  1.00001  1.00001  1.00001  1.00001
    │     1.00001  1.00001  1.00001  1.00001  1.00001  1.00001  1.00001  1.00001  1.00001  1.00001
    │     1.00001  1.00001  1.00001  1.00001  1.00001  1.00001  1.00001  1.00001  1.00001  1.00001
    └                                                   Info @ Main path.jl:101
    """


    # Basic color test
    @test genmsg(Logging.Info, "line1\nline2", Main, "some/path.jl", 101, color=true) ==
    """
    \e[1m\e[36m┌ \e[39m\e[22mline1
    \e[1m\e[36m│ \e[39m\e[22mline2
    \e[1m\e[36m└ \e[39m\e[22m                                                  \e[90mInfo @ Main path.jl:101\e[39m
    """
end

end
