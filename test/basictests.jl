using LinearSolve, LinearAlgebra, SparseArrays, MultiFloats, ForwardDiff
using SciMLOperators
using Test
import Random

const Dual64 = ForwardDiff.Dual{Nothing, Float64, 1}

n = 8
A = Matrix(I, n, n)
b = ones(n)
A1 = A / 1;
b1 = rand(n);
x1 = zero(b);
A2 = A / 2;
b2 = rand(n);
x2 = zero(b);

prob1 = LinearProblem(A1, b1; u0 = x1)
prob2 = LinearProblem(A2, b2; u0 = x2)

cache_kwargs = (; verbose = true, abstol = 1e-8, reltol = 1e-8, maxiter = 30)

function test_interface(alg, prob1, prob2)
    A1 = prob1.A
    b1 = prob1.b
    x1 = prob1.u0
    A2 = prob2.A
    b2 = prob2.b
    x2 = prob2.u0

    sol = solve(prob1, alg; cache_kwargs...)
    @test A1 * sol.u ≈ b1

    cache = SciMLBase.init(prob1, alg; cache_kwargs...) # initialize cache
    sol = solve(cache)
    @test A1 * sol.u ≈ b1

    cache = LinearSolve.set_A(cache, deepcopy(A2))
    sol = solve(cache; cache_kwargs...)
    @test A2 * sol.u ≈ b1

    cache = LinearSolve.set_A(cache, A2)
    cache = LinearSolve.set_b(cache, b2)
    sol = solve(cache; cache_kwargs...)
    @test A2 * sol.u ≈ b2

    return
end

@testset "LinearSolve" begin
    @testset "Default Linear Solver" begin
        test_interface(nothing, prob1, prob2)

        A1 = prob1.A
        b1 = prob1.b
        x1 = prob1.u0
        y = solve(prob1)
        @test A1 * y ≈ b1

        _prob = LinearProblem(Diagonal(A1), b1; u0 = x1)
        y = solve(_prob)
        @test A1 * y ≈ b1

        _prob = LinearProblem(SymTridiagonal(A1), b1; u0 = x1)
        y = solve(_prob)
        @test A1 * y ≈ b1

        _prob = LinearProblem(Tridiagonal(A1), b1; u0 = x1)
        y = solve(_prob)
        @test A1 * y ≈ b1

        _prob = LinearProblem(Symmetric(A1), b1; u0 = x1)
        y = solve(_prob)
        @test A1 * y ≈ b1

        _prob = LinearProblem(Hermitian(A1), b1; u0 = x1)
        y = solve(_prob)
        @test A1 * y ≈ b1

        _prob = LinearProblem(sparse(A1), b1; u0 = x1)
        y = solve(_prob)
        @test A1 * y ≈ b1
    end

    @testset "UMFPACK Factorization" begin
        A1 = sparse(A / 1)
        b1 = rand(n)
        x1 = zero(b)
        A2 = sparse(A / 2)
        b2 = rand(n)
        x2 = zero(b)

        prob1 = LinearProblem(A1, b1; u0 = x1)
        prob2 = LinearProblem(A2, b2; u0 = x2)
        test_interface(UMFPACKFactorization(), prob1, prob2)
        test_interface(UMFPACKFactorization(reuse_symbolic = false), prob1, prob2)

        # Test that refactoring is checked and handled.
        cache = SciMLBase.init(prob1, UMFPACKFactorization(); cache_kwargs...) # initialize cache
        y = solve(cache)
        cache = LinearSolve.set_A(cache, A2)
        @test A2 * solve(cache) ≈ b1
        X = sprand(n, n, 0.8)
        cache = LinearSolve.set_A(cache, X)
        @test X * solve(cache) ≈ b1
    end

    @testset "KLU Factorization" begin
        A1 = sparse(A / 1)
        b1 = rand(n)
        x1 = zero(b)
        A2 = sparse(A / 2)
        b2 = rand(n)
        x2 = zero(b)

        prob1 = LinearProblem(A1, b1; u0 = x1)
        prob2 = LinearProblem(A2, b2; u0 = x2)
        test_interface(KLUFactorization(), prob1, prob2)
        test_interface(KLUFactorization(reuse_symbolic = false), prob1, prob2)

        # Test that refactoring wrong is checked and handled.
        cache = SciMLBase.init(prob1, KLUFactorization(); cache_kwargs...) # initialize cache
        y = solve(cache)
        cache = LinearSolve.set_A(cache, A2)
        @test A2 * solve(cache) ≈ b1
        X = sprand(n, n, 0.8)
        cache = LinearSolve.set_A(cache, X)
        @test X * solve(cache) ≈ b1
    end

    @testset "Sparspak Factorization (Float64)" begin
        A1 = sparse(A / 1)
        b1 = rand(n)
        x1 = zero(b)
        A2 = sparse(A / 2)
        b2 = rand(n)
        x2 = zero(b)

        prob1 = LinearProblem(A1, b1; u0 = x1)
        prob2 = LinearProblem(A2, b2; u0 = x2)
        test_interface(SparspakFactorization(), prob1, prob2)
    end

    @testset "Sparspak Factorization (Float64x1)" begin
        A1 = sparse(A / 1) .|> Float64x1
        b1 = rand(n) .|> Float64x1
        x1 = zero(b) .|> Float64x1
        A2 = sparse(A / 2) .|> Float64x1
        b2 = rand(n) .|> Float64x1
        x2 = zero(b) .|> Float64x1

        prob1 = LinearProblem(A1, b1; u0 = x1)
        prob2 = LinearProblem(A2, b2; u0 = x2)
        test_interface(SparspakFactorization(), prob1, prob2)
    end

    @testset "Sparspak Factorization (Float64x2)" begin
        A1 = sparse(A / 1) .|> Float64x2
        b1 = rand(n) .|> Float64x2
        x1 = zero(b) .|> Float64x2
        A2 = sparse(A / 2) .|> Float64x2
        b2 = rand(n) .|> Float64x2
        x2 = zero(b) .|> Float64x2

        prob1 = LinearProblem(A1, b1; u0 = x1)
        prob2 = LinearProblem(A2, b2; u0 = x2)
        test_interface(SparspakFactorization(), prob1, prob2)
    end

    @testset "Sparspak Factorization (Dual64)" begin
        A1 = sparse(A / 1) .|> Dual64
        b1 = rand(n) .|> Dual64
        x1 = zero(b) .|> Dual64
        A2 = sparse(A / 2) .|> Dual64
        b2 = rand(n) .|> Dual64
        x2 = zero(b) .|> Dual64

        prob1 = LinearProblem(A1, b1; u0 = x1)
        prob2 = LinearProblem(A2, b2; u0 = x2)
        test_interface(SparspakFactorization(), prob1, prob2)
    end

    @testset "FastLAPACK Factorizations" begin
        A1 = A / 1
        b1 = rand(n)
        x1 = zero(b)
        A2 = A / 2
        b2 = rand(n)
        x2 = zero(b)

        prob1 = LinearProblem(A1, b1; u0 = x1)
        prob2 = LinearProblem(A2, b2; u0 = x2)
        test_interface(LinearSolve.FastLUFactorization(), prob1, prob2)
        test_interface(LinearSolve.FastQRFactorization(), prob1, prob2)

        # TODO: Resizing tests. Upstream doesn't currently support it.
        # Need to be absolutely certain we never segfault with incorrect
        # ws sizes.
    end

    @testset "Concrete Factorizations" begin for alg in (LUFactorization(),
                                                         QRFactorization(),
                                                         SVDFactorization(),
                                                         RFLUFactorization())
        @testset "$alg" begin test_interface(alg, prob1, prob2) end
    end end

    @testset "Generic Factorizations" begin for fact_alg in (lu, lu!,
                                                             qr, qr!,
                                                             cholesky,
                                                             #cholesky!,
                                                             #ldlt, ldlt!,
                                                             bunchkaufman, bunchkaufman!,
                                                             lq, lq!,
                                                             svd, svd!,
                                                             LinearAlgebra.factorize)
        @testset "fact_alg = $fact_alg" begin
            alg = GenericFactorization(fact_alg = fact_alg)
            test_interface(alg, prob1, prob2)
        end
    end end

    @testset "KrylovJL" begin
        kwargs = (; gmres_restart = 5)
        for alg in (("Default", KrylovJL(kwargs...)),
                    ("CG", KrylovJL_CG(kwargs...)),
                    ("GMRES", KrylovJL_GMRES(kwargs...)),
                    #           ("BICGSTAB",KrylovJL_BICGSTAB(kwargs...)),
                    ("MINRES", KrylovJL_MINRES(kwargs...)))
            @testset "$(alg[1])" begin test_interface(alg[2], prob1, prob2) end
        end
    end

    @testset "IterativeSolversJL" begin
        kwargs = (; gmres_restart = 5)
        for alg in (("Default", IterativeSolversJL(kwargs...)),
                    ("CG", IterativeSolversJL_CG(kwargs...)),
                    ("GMRES", IterativeSolversJL_GMRES(kwargs...))
                    #           ("BICGSTAB",IterativeSolversJL_BICGSTAB(kwargs...)),
                    #            ("MINRES",IterativeSolversJL_MINRES(kwargs...)),
                    )
            @testset "$(alg[1])" begin test_interface(alg[2], prob1, prob2) end
        end
    end

    @testset "KrylovKit" begin
        kwargs = (; gmres_restart = 5)
        for alg in (("Default", KrylovKitJL(kwargs...)),
                    ("CG", KrylovKitJL_CG(kwargs...)),
                    ("GMRES", KrylovKitJL_GMRES(kwargs...)))
            @testset "$(alg[1])" begin test_interface(alg[2], prob1, prob2) end
            @test alg[2] isa KrylovKitJL
        end
    end

    @testset "CHOLMOD" begin
        # Create a posdef symmetric matrix
        A = sprand(100, 100, 0.01)
        A = A + A' + 100 * I

        # rhs
        b = rand(100)

        # Set the problem
        prob = LinearProblem(A, b)
        sol = solve(prob)

        # Enforce symmetry to use Cholesky, since A is symmetric and posdef
        prob2 = LinearProblem(Symmetric(A), b)
        sol2 = solve(prob2)
        @test abs(norm(A * sol2.u .- b) - norm(A * sol.u .- b)) < 1e-12
    end

    @testset "Preconditioners" begin
        @testset "Vector Diagonal Preconditioner" begin
            x = rand(n, n)
            y = rand(n, n)

            s = rand(n)
            Pl = Diagonal(s) |> MatrixOperator
            Pr = Diagonal(s) |> MatrixOperator |> inv
            Pr = cache_operator(Pr, x)

            mul!(y, Pl, x)
            @test y ≈ s .* x
            mul!(y, Pr, x)
            @test y ≈ s .\ x

            y .= x
            ldiv!(Pl, x)
            @test x ≈ s .\ y
            y .= x
            ldiv!(Pr, x)
            @test x ≈ s .* y

            ldiv!(y, Pl, x)
            @test y ≈ s .\ x
            ldiv!(y, Pr, x)
            @test y ≈ s .* x
        end

        @testset "ComposePreconditioenr" begin
            s1 = rand(n)
            s2 = rand(n)

            x = rand(n, n)
            y = rand(n, n)

            P1 = Diagonal(s1)
            P2 = Diagonal(s2)

            P = LinearSolve.ComposePreconditioner(P1, P2)

            # ComposePreconditioner
            ldiv!(y, P, x)
            @test y ≈ ldiv!(P2, ldiv!(P1, x))
            y .= x
            ldiv!(P, x)
            @test x ≈ ldiv!(P2, ldiv!(P1, y))
        end
    end

    @testset "Sparse Precaching" begin
        n = 4
        Random.seed!(10)
        A = sprand(n, n, 0.8)
        A2 = 2.0 .* A
        b1 = rand(n)
        b2 = rand(n)

        prob = LinearProblem(copy(A), copy(b1))
        linsolve = init(prob, UMFPACKFactorization())
        sol11 = solve(linsolve)
        linsolve = LinearSolve.set_b(sol11.cache, copy(b2))
        sol12 = solve(linsolve)
        linsolve = LinearSolve.set_A(sol12.cache, copy(A2))
        sol13 = solve(linsolve)

        prob = LinearProblem(copy(A), copy(b1))
        linsolve = init(prob, KLUFactorization())
        sol21 = solve(linsolve)
        linsolve = LinearSolve.set_b(sol21.cache, copy(b2))
        sol22 = solve(linsolve)
        linsolve = LinearSolve.set_A(sol22.cache, copy(A2))
        sol23 = solve(linsolve)

        @test sol11.u ≈ sol21.u
        @test sol12.u ≈ sol22.u
        @test sol13.u ≈ sol23.u
    end

    @testset "Solve Function" begin
        A1 = rand(n) |> Diagonal
        b1 = rand(n)
        x1 = zero(b1)
        A2 = rand(n) |> Diagonal
        b2 = rand(n)
        x2 = zero(b1)

        @testset "LinearSolveFunction" begin
            function sol_func(A, b, u, p, newA, Pl, Pr, solverdata; verbose = true,
                              kwargs...)
                if verbose == true
                    println("out-of-place solve")
                end
                u = A \ b
            end

            function sol_func!(A, b, u, p, newA, Pl, Pr, solverdata; verbose = true,
                               kwargs...)
                if verbose == true
                    println("in-place solve")
                end
                ldiv!(u, A, b)
            end

            prob1 = LinearProblem(A1, b1; u0 = x1)
            prob2 = LinearProblem(A1, b1; u0 = x1)

            for alg in (LinearSolveFunction(sol_func),
                        LinearSolveFunction(sol_func!))
                test_interface(alg, prob1, prob2)
            end
        end

        @testset "DirectLdiv!" begin
            function get_operator(A, u)
                function f(du, u, p, t)
                    println("using FunctionOperator mul!")
                    mul!(du, A, u)
                end

                function fi(du, u, p, t)
                    println("using FunctionOperator ldiv!")
                    ldiv!(du, A, u)
                end

                FunctionOperator(f, u, u; isinplace = true, op_inverse = fi)
            end

            op1 = get_operator(A1, x1 * 0)
            op2 = get_operator(A2, x2 * 0)

            prob1 = LinearProblem(op1, b1; u0 = x1)
            prob2 = LinearProblem(op2, b2; u0 = x2)

            @test LinearSolve.defaultalg(op1, x1) isa DirectLdiv!
            @test LinearSolve.defaultalg(op2, x2) isa DirectLdiv!

            test_interface(DirectLdiv!(), prob1, prob2)
            test_interface(nothing, prob1, prob2)
        end
    end
end # testset
