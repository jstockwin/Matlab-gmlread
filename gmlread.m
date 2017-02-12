function [ G ] = gmlread( filepath )
%gmlread(filepath) Reads a gml file and returns a matlab graph class. 
% Node ids will be available in G.Nodes.Names, and if labels are present
% in the gml file, these will be availabe in G.Nodes.Labels
    inputfile = fopen(filepath);
       
    determined_directed = 0;
    
    node_count = 0;
    edge_count = 0;
    
    interpreting_node = 0;
    interpreting_edge = 0;
    
    node_props = {};
    num_node_props = 0;
    
    edge_props = {};
    num_edge_props = 0;

    % This map will map the ids from the file to the matlab indexes. 
    map = containers.Map('KeyType', 'double', 'ValueType', 'double');
    
    % Initial run through to find node_count and edge_count
    while 1
        tline = fgetl(inputfile);
        
        % At end of file, set pointer to start of file, then break
        if ~ischar(tline)
            frewind(inputfile);
            break
        end
        
        str = regexp(tline, '(?<=^\s*)([^ \t]+)', 'match');
        str = str{1};
        
        if strcmp(str, '[')
            continue
        elseif strcmp(str, ']')
            interpreting_node = 0;
            interpreting_edge = 0;
            continue
        elseif strcmp(str, 'node')
            interpreting_node = 1;
            node_count = node_count + 1;
        elseif strcmp(str, 'edge')
            interpreting_edge = 1;
            edge_count = edge_count + 1;
        else
            if interpreting_node
                if ~ismember(str, node_props)
                    num_node_props = num_node_props + 1;
                    node_props{num_node_props} = str;
                end
                continue
            elseif interpreting_edge
                if strcmp(str, 'source') || strcmp(str, 'target')
                    continue
                else
                    if ~ismember(str, edge_props)
                        num_edge_props = num_edge_props + 1;
                        edge_props{num_edge_props} = str;
                    end
                    continue
                end
            end
        end
 
        if ~determined_directed
           r = regexp(tline, '(?<=directed [^0-1]*)[0-1]+', 'match');
           if ~isempty(r)
               directed = str2double(r{1});
               determined_directed = 1;
           end
           continue
        end
    end
    
    % Initialise variables.
    current_node = 0;
    current_edge = 0;

    has_id = 0;
    
    has_source = 0;
    has_target = 0;
    
    EdgeTable = table(zeros(edge_count, 2), 'VariableNames', {'EndNodes'});
    EdgeProps = cell2table(repmat(cell(edge_count, 1), 1, num_edge_props), 'VariableNames', edge_props);
    EdgeTable = [EdgeTable, EdgeProps];
    NodeProps = cell2table(repmat(cell(node_count, 1), 1, num_node_props), 'VariableNames', node_props);
    while 1
        % Read next line
        tline = fgetl(inputfile);
        
        % Stop if end of file
        if ~ischar(tline)
            break
        end
        
        if ~isempty(strfind(tline, 'node'))
            current_node = current_node + 1;
            interpreting_node = 1;
            continue;
        elseif ~isempty(strfind(tline, 'edge'))
            current_edge = current_edge + 1;
            interpreting_edge = 1;
            continue;
        end
            
        str = regexp(tline, '(?<=^\s*)([^ \t]+)', 'match');
        str = str{1};

        if strcmp(str, '[')
            continue
        elseif strcmp(str, ']')
            % Done interpreting node. Check we found an id, and reset
            % values. 
            if interpreting_node && ~has_id
                fclose(inputfile);
                error('Node ID not found')
            end
            if interpreting_edge
                if has_source && has_target
                        EdgeTable{current_edge, 1} = [map(this_source) map(this_target)];
                else
                    fclose(inputfile);
                    error('Edge did not have source and target')
                end
            end
            interpreting_node = 0;
            interpreting_edge = 0;
            has_id = 0;
            has_source = 0;
            has_target = 0;
            continue
        else
            if interpreting_node
                if strcmp(str, 'id')
                    has_id = 1;
                    id = regexp(tline, '(?<=id [^0-9]*)[0-9]*\.?[0-9]+', 'match');
                    this_id = str2double(id{1});
                    NodeProps{current_node, 'id'} = {this_id};
                    map = [map; containers.Map({this_id}, {current_node})];
                    continue
                else
                    val = regexp(tline, strcat('(?<=', str, ' ).*'), 'match'); 
                    NodeProps{current_node, str} = val;
                    continue
                end
            elseif interpreting_edge
                if strcmp(str, 'source')
                    has_source = 1;
                    source = regexp(tline, '(?<=source [^0-9]*)[0-9]*\.?[0-9]+', 'match');
                    this_source = str2double(source{1});
                    continue
                elseif strcmp(str, 'target')
                    has_target = 1;
                    target = regexp(tline, '(?<=target [^0-9]*)[0-9]*\.?[0-9]+', 'match');
                    this_target = str2double(target{1});
                    continue
                else
                    val = regexp(tline, strcat('(?<=', str, ' ).*'), 'match');
                    EdgeTable{current_edge, str} = val;
                    continue
                end
            end
        end
    end
    if directed
        try
            G = digraph(EdgeTable, NodeProps);
        catch err
            if strcmp(err.identifier, 'MATLAB:graphfun:graphbuiltin:DuplicateEdges')
                warning('Duplicate edges detected. These will be ignored')
                [~, idx] = unique(EdgeTable(:,1));
                EdgeTable = EdgeTable(idx,:);
                G = digraph(EdgeTable, NodeProps);
            else
                rethrow(err)
            end
        end
    else
        try
            G = graph(EdgeTable, NodeProps);
        catch err
            if strcmp(err.identifier, 'MATLAB:graphfun:graphbuiltin:DuplicateEdges')
                warning('Duplicate edges detected. These will be ignored')
                [~, idx] = unique(EdgeTable(:,1));
                EdgeTable = EdgeTable(idx,:);
                G = graph(EdgeTable, NodeProps);
            else
                rethrow(err)
            end
        end
    end
    fclose(inputfile);

end

