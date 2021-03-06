#' Clean input CREDI response data
#'
#' This calculates the posterior density function.
#' @param input_df (data.frame) Raw input data from the user-specified csv file.
#' @param mest_df (data.frame) Measurement parameter estimates.
#' @param csv_wd (string) Working directory where input *.csv file is located.
#' @param reverse_code (logical). If TRUE, then reverse codes LF9, LF102, LFMH1, LFMH2, LFMH3, LFMH4, LFMH5, LFMH7, LFMH8, & LFMH9. If FALSE, then no reverse coding is applied.
#' @param log (string) Name of the *.txt log file for the CREDI scoring.
#' @keywords CREDI
#' @export
#' @examples
#' clean(input_df, mest_df, reverse_code, interactive, log)


clean<-function(input_df, mest_df, reverse_code, interactive, log){
  # Input:
  #  input_df - User defined input file, with:
  #                 a) LF item naming convention needed.
  #                 b) Unique identifier needed.
  #                 c) Age in month needed
  #  mest_df - Item parameters and other information like naming conversion and reverse coding.
  #  reverse_code - (logical) If TRUE then reverse codes long form items that are negatively worded.
  #                           Otherwise does not implement reverse coding.
  # Output: List with the following:
  #  cleaned_df - Cleaned data (i.e., missing data codes, reverse coding as necessary)
  #  items_noresponse - character vector with items missing all responses

  stop = 0



  names(input_df) = toupper(names(input_df))
  # Ensure that there is a unique ID variable for each observations
  if (!"ID"%in%names(input_df)){
    stop = 1
    stop_message = "\n* Error: An identifier variable named ID must be included."
    log[[length(log)+1]] = stop_message
  }
  if (sum(is.na(input_df$ID))>0){
    stop = 1
    stop_message = "\n* Error: Values of ID variable missing for some observations. Each observation must have a unique ID value."
    log[[length(log)+1]] = stop_message
  }
  if (length(unique(input_df$ID))<nrow(input_df)){
    stop = 1
    stop_message = "\n* Error: Values of ID are not unique across observations. Construct a unique identifier and re-run."
    log[[length(log)+1]] = stop_message
  }


  # Check that AGE is in the response data
  if (!"AGE"%in%names(input_df)){
    stop = 1
    stop_message = "\n* Error: An AGE variable named must be included. Scoring requires children's age in months."
    log[[length(log)+1]] = stop_message
  }

  if (stop == 1){
    out_list = list(cleaned_df = NULL, items_noresponse = NULL, stop = stop, log = log)
    return(out_list)
  }


  #Ignore variables that


  vecQnames = c(mest_df$Item, mest_df$CREDI_code, mest_df$CREDI_code_Apr17)
  vecQnames = c("ID","AGE",vecQnames[complete.cases(vecQnames)])
  j_ignore = which(!names(input_df)%in%vecQnames)
  if (length(j_ignore)>0){
    log[[length(log)+1]] = paste("\n* Warning: The following variables will be ignored during scoring: ", paste(names(input_df)[j_ignore], collapse = ", "), sep = "")
    input_df = input_df[,-j_ignore]
  }


  # Ensure the naming of the response data is in the correct format
  j_AGE_ID = c( which(names(input_df)=="ID"), which(names(input_df)=="AGE") )

  key_df = data.frame(
    rbind( cbind(mest_df$CREDI_code, mest_df$CREDI_code),
           cbind( mest_df$CREDI_code, mest_df$Item),
           cbind( mest_df$CREDI_code, mest_df$CREDI_code_Apr17))
  )
  key_df = key_df[complete.cases(key_df), ]
  names(key_df) = c("CREDI_code", "Other")
  key_df$CREDI_code = as.character(key_df$CREDI_code)
  key_df$Other = as.character(key_df$Other)

  unknown_vars = NULL
  rename_df = data.frame(orig = rep(NA, ncol(input_df)), new = rep(NA, ncol(input_df)))
  for (j in 1:ncol(input_df)){
    if (names(input_df)[j]=="AGE"){
      rename_df$orig[j] <-rename_df$new[j]<- "AGE"
    } else if (names(input_df)[j]=="ID"){
      rename_df$orig[j] <-rename_df$new[j]<- "ID"
    } else{
      jkey = which(key_df$Other == names(input_df)[j])

      if (length(jkey)==1){
        rename_df$orig[j] = names(input_df)[j]
        rename_df$new[j] = key_df$CREDI_code[jkey]
      }
      if (length(jkey)==0){
        rename_df$orig[j] = names(input_df)[j]
        unknown_vars = c(unknown_vars,names(input_df)[j])}
    }
  }

  # Check if there were unknown variable names and print them out
  if (!is.null(unknown_vars)){
    stop = 1
    stop_message = paste("\n* Error: Unknown variable names: ", paste(unknown_vars, collapse = ", "), sep = "")
    log[[length(log)+1]] = stop_message
  }

  if (stop == 1){
    out_list = list(cleaned_df = NULL, items_noresponse = NULL, stop = stop, log = log)
    return(out_list)
  }

  # Check if there were redundancy in original or recoded leads to redundant variable names
  vnfreq_orig = data.frame(table(rename_df$orig)); names(vnfreq_orig) = c("orig","freq_orig")
  inds = which(vnfreq_orig$freq_orig>1)
  if (length(inds)>0){
    stop = 1
    stop_message = "\n* Error: Non-unique variable names: "

    log[[length(log)+1]] = paste(stop_message,
                                 paste(vnfreq_orig$orig[inds], collapse = ", "), sep = "" )

  }


  vnfreq_new = data.frame(table(rename_df$new)); names(vnfreq_new) = c("new","freq_new")
  rename_df = merge(x = rename_df, y = vnfreq_new, by = "new", all.x = TRUE, all.y = TRUE, sort = FALSE)

  inds = which(rename_df$freq_new>1)
  if (length(inds)>0){
    stop = 1
    stop_message = "\n* Error: When recoding variable names to the latest convention, one or more of the original
    variables mapped to the same recoded variable."
    tmp = c("original.variable --> recoded.variable")
    for (iii in 1:length(inds)){
      tmp = c(tmp, paste(rename_df$orig[inds[iii]], rename_df$new[inds[iii]], sep = " --> "))
    }
    log[[length(log)+1]]  = c(stop_message, tmp)
  }

  if (stop == 1){
    out_list = list(cleaned_df = NULL, items_noresponse = NULL, stop = stop, log = log)
    return(out_list)
  }


  # Finally recode the variable
  names(input_df) = rename_df$new

  # Check that all variables outside of ID are numeric
  not_numeric = NULL
  for (j in seq(1,ncol(input_df))){
    if(names(input_df)[j]!="ID"){
      if (sum(is.na(input_df[,j]))!=length(input_df[,j])) {
        if( !is.numeric(input_df[,j]) ){
          new_name = names(input_df)[j]
          old_name = rename_df$orig[rename_df$new == new_name]
          not_numeric = c(not_numeric,old_name)
        }
      }
    }
  }
  if (!is.null(not_numeric)){
    stop = 1
    stop_message = "\n* Error: AGE and all item response variables must be in numeric format. At least one of these variables may contain non-numeric values:"
    log[[length(log)+1]] = c(stop_message,
                             paste(not_numeric, collapse = ", ") )
  }

  if (stop == 1){
    out_list = list(cleaned_df = NULL, items_noresponse = NULL, stop = stop, log = log)
    return(out_list)
  }

  # Create a log of number of observations that must be discarded
  N_input = nrow(input_df)
  discard_df = data.frame(Reason = rep(NA,3), Number = rep(NA,3))
  dr = 0

  # Clean the AGE as needed
  #input_df$AGE[c(2, 16, 28, 45:50)] = NA # works
  # Missing age
  rows_mi_age = which(is.na(input_df$AGE))
  if (length(rows_mi_age)>0){
    log[[length(log)+1]] =
      paste("\n* Warning: ", length(rows_mi_age) , " observation(s) are missing AGE values and cannot be scored (ID = ", paste(input_df$ID[rows_mi_age], collapse = ", "), sep = "")
    dr = dr+1; discard_df$Reason[dr] = "Missing age values"; discard_df$Number[dr] = length(rows_mi_age)
    input_df = input_df[-rows_mi_age, ]
  }

  # Age outside of range.
  if (nrow(input_df)>0){
    rows_out_age = which(input_df$AGE<0 | input_df$AGE>36)
    if (length(rows_out_age)>0){
      log[[length(log)+1]] =
        paste("\n* Warning:  The following ", length(rows_out_age) ," observation(s) cannot be scored because the AGE values are outside of 0-36 months: (ID = ", paste(input_df$ID[rows_out_age], collapse = ", "),")", sep = "")
      dr = dr+1; discard_df$Reason[dr] = "Age values outside of 0-36 months"; discard_df$Number[dr] = length(rows_out_age)
      input_df = input_df[-rows_out_age, ]
    }
  }

  if (nrow(input_df)>0){
    # Clean the missing responses data
    cols_Q = which(startsWith(names(input_df), "LF"))
    temp_df = input_df[,cols_Q]
    temp_df[temp_df!=0L & temp_df!=1L] = NA

    # Discard observations with fewer than 5 item responses
    num_nonmi_y = apply(temp_df, MARGIN = 1L, function(X){sum(!is.na(X))})
    rows_toofew_y = which(num_nonmi_y<5L)
    if (length(rows_toofew_y)>0){
      log[[length(log)+1]] =
        paste("\n* Warning:  The following ", length(rows_toofew_y) ," observation(s) contain less than 5 non-missing item responses and will not be scored:\n  ID = ", paste(input_df$ID[rows_toofew_y], collapse = ", "), sep = "")
      dr = dr+1; discard_df$Reason[dr] = "Less than 5 item responses"; discard_df$Number[dr] = length(rows_toofew_y)
      input_df = input_df[-rows_toofew_y, ]
    }
  }

  # Check if there are any remaining observations to score

  if (nrow(input_df)==0){
    stop = 1
    stop_message = paste("\n* Error:\n  All ", N_input," observations have been discarded for the following reason(s): \n", sep = "")
    print(stop_message)
    print(discard_df[complete.cases(discard_df), ])
    log[[length(log)+1]] =  stop_message
    log[[length(log)+1]] = discard_df[complete.cases(discard_df), ]
  }

  if (stop == 1){
    out_list = list(cleaned_df = NULL, items_noresponse = NULL, stop = stop, log = log)
    return(out_list)
  }

  # Check if they want to continue given the discarding
  if(nrow(input_df)<N_input){
    discard_df = discard_df[complete.cases(discard_df), ]
    discard_df = transform(discard_df, Percent = paste(round(100*Number/N_input,1),"%",sep = ""))
    N_discarded = sum(discard_df$Number); Pct_discarded = round(100*N_discarded/N_input,1)

    log[[length(log)+1]] =  paste("\n* Warning:  A total of ", N_discarded, " (", Pct_discarded,"%) observation(s) cannot be scored for the following reason(s):",sep ="")
    log[[length(log)+1]] = discard_df[complete.cases(discard_df), ]

    if (interactive == FALSE){
      x = "Y"
    } else {
      print(paste("\n* Warning:  A total of ", N_discarded, " (", Pct_discarded,"%) observation(s) cannot be scored for the following reason(s):",sep =""))
      print(discard_df[complete.cases(discard_df), ])
      x<-as.character(readline(prompt = "Would you like to continue? [Y/N]: "))
    }
    x <- toupper(x)

    cut = 0
    while(cut == 0){

      if (x == "Y"){
        cut = 1;
      } else if (x == "N"){
        cut = 1
        stop("Scoring canceled.", call. = FALSE)
      } else {
        x<-as.character(readline(prompt = "Would you like to continue? [Y/N]:"))
        x <- toupper(x)
        cut = 0
      }

    } #end while

  } # end if


  # Create the cleaned_df version
  N = nrow(input_df)
  cleaned_df = data.frame(mat.or.vec(nr = N, nc = nrow(mest_df)+2)+NA)
  names(cleaned_df) = c("ID","AGE", mest_df$CREDI_code)
  cleaned_df$ID = input_df$ID; cleaned_df$AGE = input_df$AGE
  for (j in cols_Q){

    # Only bring in answers that are 1 or 0. Otherwise keep missing
    col_j = which( names(cleaned_df) %in% names(input_df)[j] )
    rows_j = which(input_df[,j] == 1L | input_df[,j]==0)
    cleaned_df[rows_j,col_j] = input_df[rows_j,j]

  }


  # Print out missing data descriptive statistics
  miss_df = data.frame(round(100*apply(cleaned_df[,-c(1,2)], 2, function(X){sum(is.na(X))})/N,2))
  names(miss_df) = c("Pct_Missing")
  miss_df = subset(miss_df, Pct_Missing>0)
  if (nrow(miss_df)>0){

    items_noresponse = row.names(miss_df)[miss_df$Pct_Missing==100]

    inds_order = sort(miss_df$Pct_Missing, decreasing = TRUE, index.return = TRUE)
    miss_df2 = data.frame(Item = row.names(miss_df)[inds_order$ix], Pct_Missing = miss_df$Pct_Missing[inds_order$ix])

    # if (length(items_noresponse)>0){
    #
    #   log[[length(log)+1]]  = c(paste("\nThe following items on the long form contained missing responses from all individuals: ",
    #                      paste(subset(miss_df2, Pct_Missing==100)$Item, collapse = ", "), sep = ""))
    # }

    miss_df3 = miss_df2
    miss_df3 = transform(miss_df3, Pct_Missing = round(Pct_Missing, 1))
    miss_df3 = transform(miss_df3, Pct_Missing = paste(Pct_Missing,"%", sep = ""));



    log[[length(log)+1]] = "\nMissingness rates of items responses:"
    log[[length(log)+1]] = miss_df3

  }

  reversed_items = NULL
  if (reverse_code == TRUE){
    # Reverse code as needed
    items_reverse = mest_df$CREDI_code[mest_df$RevCoded]
    cols_reverse = which(!is.na(match(names(cleaned_df),items_reverse)))
    for (j in cols_reverse){
      rows_j = which(cleaned_df[,j]==1L | cleaned_df[,j]==0L)
      cleaned_df[rows_j,j] = as.integer(1L-cleaned_df[rows_j,j])
      new_name = names(cleaned_df)[j]
      old_name = rename_df$orig[rename_df$new == new_name]
      reversed_items = c(reversed_items, old_name)
    }

    log[[length(log)+1]] =paste("*\nNote that reverse_code set to TRUE. As a result, the following items have been reverse coded automatically: ", paste(reversed_items, collapse = ", "), sep = "")

  }


  out_list = list(cleaned_df = cleaned_df, items_noresponse = items_noresponse, stop = stop, log = log)

  return(out_list)
}
