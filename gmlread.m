function [ G ] = gmlread( file_path )
%gmlread Reads a gml file and returns the adjacency matrix
    inputfile = fopen(file_path);
    
    interpreting_node = 0;
    interpreting_edge = 0;
    
    determined_directed = 0;
    
    node_count = 0;
    edge_count = 0;
    
    node_ids = {};
    node_labels = {};
    
    has_id = 0;
    has_label = 0;
    
    has_source = 0;
    has_target = 0;
    
    % This map will map the ids from the file to the matlab indexes. 
    map = containers.Map('KeyType', 'double', 'ValueType', 'double');
    
    while 1
        % Read next line
        tline = fgetl(inputfile);
        
        % Stop if end of file
        if ~ischar(tline)
            break
        end
        
        if ~determined_directed
           r = regexp(tline, '(?<=directed [^0-1]*)[0-1]+', 'match');
           if ~isempty(r)
               directed = str2double(r{1});
               determined_directed = 1;
                          % TODO: Handle directed graphs!
               if directed
                   error('Directed graphs not currently supported')
               end
           end
           
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
            label = regexp(tline, '(?<=label ).*', 'match');
            done = ~isempty(strfind(tline, ']'));
            
            if ~isempty(id)
                has_id = 1;
                this_id = str2double(id{1});
            end
            
            if ~isempty(label)
                has_label = 1;
                this_label = label{1};
            end
            
            if done
                node_count = node_count + 1;
                if has_id
                    node_ids{node_count} = this_id;
                    map = [map; containers.Map({this_id}, {node_count})];
                end
                if has_label
                    node_labels{node_count} = this_label;
                end
                has_label = 0;
                has_id = 0;
                interpreting_node = 0;
            end
            
        end
        
        
        if interpreting_edge
            source = regexp(tline, '(?<=source [^0-9]*)[0-9]*\.?[0-9]+', 'match');
            target = regexp(tline, '(?<=target [^0-9]*)[0-9]*\.?[0-9]+', 'match');
            done = ~isempty(strfind(tline, ']'));
            
            if ~isempty(source)
                has_source = 1;
                this_source = str2double(source{1});
            end
            if ~isempty(target)
                has_target = 1;
                this_target = str2double(target{1});
            end
            
            if done
               if has_source && has_target
                   edge_count = edge_count + 1;
                   if edge_count == 1
                       EdgeTable = table([this_source+1 this_target+1], 'VariableNames', {'EndNodes'});
                   else 
                       EdgeTable = [EdgeTable; {[map(this_source) map(this_target)]}];
                   end
                   
               else
                   fclose(inputfile);
                   error('Bad things')
               end
               interpreting_edge = 0;
            end
            
        end
        
        
        
    end
    
    NodeProps = table(node_ids', node_labels', 'VariableNames', {'id', 'label'});
    G = addnode(graph(), NodeProps);
    G = addedge(G, EdgeTable);
    fclose(inputfile);

end

