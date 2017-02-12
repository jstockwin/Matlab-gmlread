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
        
        if interpreting_node
            if strcmp(str, '[')
                continue
            elseif strcmp(str, ']')
                interpreting_node = 0;
                continue
            else
                if ~ismember(str, node_props)
                    num_node_props = num_node_props + 1;
                    node_props{num_node_props} = str;
                end
                continue
            end
        elseif interpreting_edge
            % TODO: Handle edge props other than source and target here?
            continue;
        else
            if strcmp(str, 'node')
                interpreting_node = 1;
                node_count = node_count + 1;
            elseif strcmp(str, 'edge')
                interpreting_edge = 1;
                edge_count = edge_count + 1;
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
        
        if interpreting_node
            
            str = regexp(tline, '(?<=^\s*)([^ \t]+)', 'match');
            str = str{1};
            
            if strcmp(str, '[')
                continue
            elseif strcmp(str, ']')
                % Done interpreting node. Check we found an id, and reset
                % values. 
                interpreting_node = 0;
                if ~has_id
                    fclose(inputfile);
                    error('Node ID not found')
                end
                has_id = 0;
                continue
            elseif strcmp(str, 'id')
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
        end
        
        
        if interpreting_edge
            source = regexp(tline, '(?<=source [^0-9]*)[0-9]*\.?[0-9]+', 'match');
            target = regexp(tline, '(?<=target [^0-9]*)[0-9]*\.?[0-9]+', 'match');
            done = ~isempty(strfind(tline, ']'));
            
            if ~isempty(source)
                has_source = 1;
                this_source = str2double(source{1});
                continue
            end
            if ~isempty(target)
                has_target = 1;
                this_target = str2double(target{1});
                continue
            end
            
            if done
               if has_source && has_target
                   EdgeTable{current_edge, 1} = [map(this_source) map(this_target)];          
               else
                   fclose(inputfile);
                   error('Bad things')
               end
               interpreting_edge = 0;
               continue
            end
            continue
        end
    end
    if directed
        G = digraph(EdgeTable, NodeProps);
    else
        G = graph(EdgeTable, NodeProps);
    end
    fclose(inputfile);

end

