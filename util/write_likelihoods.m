function [] = write_likelihoods(kal_root,dat_dir,nn_model)
% Takes as input , location of Kaldi source, a data directory 
% with NN input data and a neural net model to use for forward
% propagation, data will be written in kaldi readable binary
% format to file 'loglikelihoods.ark' in data_dir

% Inputs:
% 
% kal_root :  root of Kaldi source
% dat_dir  :  directory where data to forward prop resides, note
%             this is also where the binary likelihoods will be 
%             dumped
% nn_model :  info needed to call forward propagate (code not yet written)
   
%%Setup
%File where log likelihoods are written
ll_out = [dat_dir 'loglikelihoods.ark'];

%Load features alignments and keys
[feats alis utt_dat] = load_kaldi_data(dat_dir);

%Load priors from ali_train_pdf.counts
prior_file = 'kaldi-trunk/egs/swbd/s5/exp/tri4a_dnn/ali_train_pdf.counts';
priors = load([kal_root prior_file]);

%Take log of inverse priors and scale
prior_scale = 1;  %Use to change weight of NN vs Priors
priors = -prior_scale*log(priors./sum(priors));

%Replace any inf values with max prior value
priors(find(priors==inf)) = -inf;
maxp = max(priors);
priors(find(priors==-inf)) = maxp;

numStates = size(priors,2); %Number of HMM states
numUtts = length(utt_dat.keys); %Number of utterances

%%Forward prop and write likelihoods to output
  
%open log likelihood file to write
fid = fopen(ll_out,'w');

chunkSize = 100; %Size of utterance chunks to forward prop at a time
numChunks = ceil(numUtts/100);
numDone = 0; %Number of total frames written
numUttsDone = 0; %Number of utterances written

for i=1:numChunks

  %Get subset of keys and subset of sizes to forward prop and write
  if i==numChunks
    subKeys=utt_dat.keys((i-1)*chunkSize+1:end);
    subSizes=utt_dat.sizes((i-1)*chunkSize+1:end,:);
  else
    subKeys=utt_dat.keys((i-1)*chunkSize+1:i*chunkSize);
    subSizes=utt_dat.sizes((i-1)*chunkSize+1:i*chunkSize,:);
  end

  input = feats(numDone+1:numDone+1+sum(subSizes),:);    
    
  %%%%%%%%%%%%%
  %TODO Load Neural Net
  %TODO Forward Prop input
  output = rand(size(input,1),size(priors,2)); %filler data
  %%%%%%%%%%%%%

  %take log of forward propped dat and add log inverse priors
  output = bsxfun(@plus,log(output),priors);

  %Write each utterance separately so we can write as key value pairs
  numFramesWrit = 0;
  for u=1:length(subKeys)
    uttSize = subSizes(u);
    FLOATSIZE=4;
    %write each key with corresponding nnet value
    fprintf(fid,'%s ',subKeys{u}); % write key
    fprintf(fid,'%cBFM ',char(0)); % write Kaldi header
    fwrite(fid,FLOATSIZE,'integer*1'); %write size of float as 1
                                       %byte int
    fwrite(fid,uttSize,'int'); % write number rows
    fwrite(fid,FLOATSIZE,'integer*1'); %write size of float as 1
                                       %byte int
    fwrite(fid,numStates,'int');  % write number cols

    % write full utterance (have to transpose as fwrite is column order
    fwrite(fid,output(numFramesWrit+1:numFramesWrit+uttSize,:)', ...
           'float'); 

%% Commented out writing text version, replaced with writing binary version
%% which is significantly faster
% $$$       fprintf(fid,'%s  [\n  ',subKeys{u});
% $$$     
% $$$       %Write each row of mat separately
% $$$       for j=1:uttSize
% $$$         fprintf(fid,'%g ',output(numFramesWrit+j,:));
% $$$         if j==uttSize
% $$$           fprintf(fid,']\n');
% $$$         else
% $$$           fprintf(fid,'\n');
% $$$         end
% $$$       end


     numFramesWrit = numFramesWrit+uttSize;

  end
  numUttsDone = numUttsDone+length(subKeys);
  fprintf('%d of %d utterances written\n',numUttsDone,numUtts);
end

%close log likelihood file
fclose(fid);

end