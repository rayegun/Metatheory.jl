# example assuming * operation is always binary

# ENV["JULIA_DEBUG"] = Metatheory

abstract type NumberFold <: AbstractAnalysis end

# This should be auto-generated by a macro
function EGraphs.make(an::Type{NumberFold}, g::EGraph, n::ENode)
    # @show n
    n.head isa Number && return n.head

    op_times, _ = addexpr!(g, :*)
    op_plus, _ = addexpr!(g, :+)

    if n.head == :call && arity(n) == 3
        op = geteclass(g, n.args[1])
        l = geteclass(g, n.args[2])
        r = geteclass(g, n.args[3])
        ldata = getdata(l, an, nothing)
        rdata = getdata(r, an, nothing)

        # @show ldata rdata

        if ldata isa Number && rdata isa Number
            if in_same_class(g, op, op_times)
                return ldata * rdata
            elseif in_same_class(g, op, op_plus)
                return ldata + rdata
            end
        end
    end

    return nothing
end

function EGraphs.join(an::Type{NumberFold}, from, to)
    # println("joining!")
    if from isa Number
        if to isa Number
            @assert from == to
        else return from
        end
    end
    return to
end

function EGraphs.modify!(an::Type{NumberFold}, g::EGraph, id::Int64)
    # !haskey(an, id) && return nothing
    eclass = g.classes[id]
    d = getdata(eclass, an, nothing)
    if d isa Number
        newclass, _ = addexpr!(g, d)
        merge!(g, newclass.id, id)
    end
end

EGraphs.islazy(x::Type{NumberFold}) = false

comm_monoid = @theory begin
    a * b => b * a
    a * 1 => a
    a * (b * c) => (a * b) * c
end

G = EGraph(:(3 * 4))
analyze!(G, NumberFold)

# exit(0)

@testset "Basic Constant Folding Example - Commutative Monoid" begin
    @test (true == @areequalg G comm_monoid 3 * 4 12)

    @test (true == @areequalg G comm_monoid 3 * 4 12 4*3  6*2)
end

# Metatheory.EGraphs.PRINTIT[] = true
# Metatheory.options.verbose = true
# Metatheory.options.printiter = true

@testset "Basic Constant Folding Example 2 - Commutative Monoid" begin
    ex = :(a * 3 * b * 4)
    G = EGraph(cleanast(ex))
    analyze!(G, NumberFold)
    addexpr!(G, :(12*a))
    println(saturate!(G, comm_monoid))
    display(G.classes); println()
    @test (true == @areequalg G comm_monoid (12*a)*b ((6*2)*b)*a)
    @test (true == @areequalg G comm_monoid (3 * a) * (4 * b) (12*a)*b ((6*2)*b)*a)
end

@testset "Basic Constant Folding Example - Adding analysis after saturation" begin
    G = EGraph(:(3 * 4))
    # addexpr!(G, 12)
    saturate!(G, comm_monoid)
    addexpr!(G, :(a * 2))
    analyze!(G, NumberFold)
    saturate!(G, comm_monoid)

    # display(G.classes); println()
    # println(G.root)
    # display(G.analyses[1].data); println()

    @test (true == areequal(G, comm_monoid, :(3 * 4), 12, :(4*3), :(6*2)))

    ex = :(a * 3 * b * 4)
    G = EGraph(cleanast(ex))
    analyze!(G, NumberFold)
    params=SaturationParams(timeout=15)
    @test areequal(G, comm_monoid, :((3 * a) * (4 * b)), :((12*a)*b),
        :(((6*2)*b)*a); params=params)
end

@testset "Infinite Loops analysis" begin
    boson = @theory begin
        1 * x => x
    end

    G = EGraph(Util.cleanast( :(1 * x) ))
    params=SaturationParams(timeout=100)
    saturate!(G,boson, params)
    ex = extract!(G, ExtractionAnalysis{astsize})

    # println(ex)

    using Metatheory.EGraphs
    boson = @theory begin
        (:c * :cdag) => :cdag * :c + 1
        a * (b + c) => (a * b) + (a * c)
        (b + c) * a => (b * a) + (c * a)
        # 1 * x => x
        (a * b) * c => a * (b * c)
        a * (b * c) => (a * b) * c
    end

    G = EGraph(Util.cleanast( :(c * c * cdag * cdag) ))
    saturate!(G,boson)
    ex = extract!(G, astsize_inv)

    # println(ex)
end
