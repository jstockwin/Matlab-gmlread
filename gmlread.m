function [ G ] = gmlread( filepath )
%gmlread(filepath) Reads a gml file and returns a matlab graph class. 
% Node ids will be available in G.Nodes.Names, and if labels are present
% in the gml file, these will be availabe in G.Nodes.Labels
    inputfile = fopen(filepath);
       
    determined_directed = 0;
    determined_labels = 0;
    
    node_count = 0;
    edge_count = 0;
    
    has_labels = 0;

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
        
        
        if ~determined_directed
           r = regexp(tline, '(?<=directed [^0-1]*)[0-1]+', 'match');
           if ~isempty(r)
               directed = str2double(r{1});
               determined_directed = 1;
                          % TODO: Handle directed graphs!
               if directed
                   fclose(inputfile);
                   error('Directed graphs not currently supported')
               end
           end
           continue
        end
        
        if ~determined_labels
            r = regexp(tline, 'label', 'match');
            if ~isempty(r)
                has_labels = 1;
                determined_labels = 1;
            end
            continue
        end
        
        if ~isempty(strfind(tline, 'node'))
            node_count = node_count + 1;
            continue;
        elseif ~isempty(strfind(tline, 'edge'))
            edge_count = edge_count + 1;
            continue;
        end
        
    end
    
    % Initialise variables.
    interpreting_node = 0;
    interpreting_edge = 0;
    
    current_node = 0;
    current_edge = 0;

    has_id = 0;
    has_label = 0;
    
    has_source = 0;
    has_target = 0;
    
    EdgeTable = table(zeros(edge_count, 2), 'VariableNames', {'EndNodes'});
    
    if has_labels
        NodeProps = table(cell(node_count,1), cell(node_count,1), 'VariableNames', {'Names', 'Labels'});
    else
        NodeProps = table(cell(node_count,1), 'VariableNames', {'id'});
    end
        
    
    while 1
        % Read next line
        tline = fgetl(inputfile);
        
        % Stop if end of file
        if ~ischar(tline)
            break
        end
        
        if ~isempty(strfind(tline, 'node'))
            interpreting_node = 1;
            continue;
        elseif ~isempty(strfind(tline, 'edge'))
            interpreting_edge = 1;
            continue;
        end
        
        if interpreting_node
            id = regexp(tline, '(?<=id [^0-9]*)[0-9]*\.?[0-9]+', 'match');
            done = ~isempty(strfind(tline, ']'));
            
            if ~isempty(id)
                has_id = 1;
                this_id = str2double(id{1});
                continue
            end
            
            if has_labels
                label = regexp(tline, '(?<=label ).*', 'match');
                if ~isempty(label)
                    has_label = 1;
                    this_label = label{1};
                    continue
                end
            end
            
            if done
                current_node = current_node + 1;
                if has_labels
                    if ~has_label
                        warning('Missing label, setting to ""');
                        this_label = ''; 
                    end
                    if has_id && has_label
                        NodeProps{current_node,:} = {this_id, this_label};
                        map = [map; containers.Map({this_id}, {current_node})];
                    else
                        fclose(inputfile);
                        error('Node ID or label not found')
                    end
                    has_label = 0;
                else
                    if has_id
                        NodeProps{current_node,1} = {this_id};
                        map = [map; containers.Map({this_id}, {current_node})];
                    else
                        fclose(inputfile);
                        error('Node ID not found')
                    end
                end
                has_id = 0;
                interpreting_node = 0;
                continue
            end
            continue
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
                   current_edge = current_edge + 1;
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
    G = addnode(graph(), NodeProps);
    G = addedge(G, EdgeTable);
    fclose(inputfile);

end

