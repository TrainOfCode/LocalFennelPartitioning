include("sfc_den.jl")

function get_order(G::Dict{Int64, Vector{Int64}})
    ord = [-1 for i in 1:length(G)]
    visited = [false for i in 1:length(G)]

    S = Vector{Int64}()
    push!(S, 2)
    place = 1

    while length(S) != 0
        curr = pop!(S)
        if (!visited[curr])
            ord[place] = curr
            place += 1
            visited[curr] = true
            for entr in G[curr]
                if (!visited[entr])
                    push!(S, entr)
                end
            end
        end
    end
    return ord
end

function distance(curr_node::Vector{Float64}, cent::Vector{Float64})
    return sum([c*c for c in curr_node - cent])^(0.5)
end

function find_distances(curr_node::Vector{Float64}, centers::Dict{Int64, Vector{Float64}})
    dist = Dict{Int64, Float64}()
    for (i, cent) in centers
        dist[i] = distance(curr_node, cent)
    end
    return dist
end

function c(size, alpha, gamma)
    return alpha * (size ^ gamma)
end

function g_local(all_cand, curr_cand_to_add_node, partition_edges, alpha, gamma, neighbor_lookup)
    sum = 0.0
    for k in all_cand
        inside_edges = partition_edges[k]["inside"]
        size = partition_edges[k]["len"]
        if curr_cand_to_add_node == k
            size += 1
            for (neigh, loc) in neighbor_lookup
                if loc == curr_cand_to_add_node
                    inside_edges += 1
                end
            end
        end
        sum += inside_edges - c(size, alpha, gamma)
    end
    return sum
end

function local_fennel(G::Dict{Int64, Vector{Int64}}, locations::Dict{Int64, Vector{Float64}}, num_p::Int64, alpha::Float64, gamma::Float64, to_cons::Int64)
    partitions = Dict(i => Vector{Int64}() for i in 1:num_p)
    lookups = Dict(i => -1 for i in 1:length(G))
    partition_edges = Dict(i => Dict("len" => 0, "inside" => 0) for i in 1:num_p)

    den_sfc_parts, den_sfc_lookups = build_den_sfc(G, num_p)
    centers = Dict(i => Vector{Float64}() for i in 1:num_p)

    for (i, part) in den_sfc_parts
        curr_center = [0 for i in 1:length(locations[1])]
        for entr in part
            curr_center += locations[entr]
        end

        centers[i] = curr_center/length(part)
    end

    threshold_update_centers = length(G)/(num_p * num_p)

    order = get_order(G)
    for curr_node in order
        neighbors = G[curr_node]

        neighbor_lookup = Dict{Int64, Int64}()
        for neigh in neighbors
            if lookups[neigh] != -1
                neighbor_lookup[neigh] = lookups[neigh]
            end
        end

        cand = Vector{Float64}()
        distances_to_centers = find_distances(locations[curr_node], centers)

        for i in 1:to_cons
            min_dist = minimum([dist for (p, dist) in distances_to_centers if p ∉ cand])
            push!(cand, [p for (p, dist) in distances_to_centers if dist == min_dist][1])
        end

        g_score = Dict{Int64, Float64}()
        for can in cand
            # g_local(cand, i, partition_edges, alpha, gamma, cand_part_i[i], neighbor_lookup, cand_part_i);
            g_score[can] = g_local(cand, can, partition_edges, alpha, gamma, neighbor_lookup)
        end

        max_cand = maximum([score for (p, score) in g_score])
        choice = [p for (p, score) in g_score if score == max_cand][1]

        lookups[curr_node] = choice
        push!(partitions[choice], curr_node)

        partition_edges[choice]["len"] += 1
        for neigh in neighbors
            if lookups[neigh] == choice && choice != -1
                partition_edges[choice]["inside"] += 1
            end
        end

        if (partition_edges[choice]["len"] > threshold_update_centers)
            centers[choice] = (centers[choice] * (partition_edges[choice]["len"] - 1) + locations[curr_node]) / partition_edges[choice]["len"]
        end
    end
    return partitions, lookups
end