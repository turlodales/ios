//
//  CCSection.m
//  Crypto Cloud Technology Nextcloud
//
//  Created by Marino Faggiana on 04/02/16.
//  Copyright (c) 2014 TWS. All rights reserved.
//
//  Author Marino Faggiana <m.faggiana@twsweb.it>
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

#import "CCSection.h"

#import "CCMetadata.h"
#import "CCCoreData.h"
#import "CCExifGeo.h"

@implementation CCSectionDataSource

- (id)init {
    
    self = [super init];
    
    _allRecordsDataSource = [[NSMutableDictionary alloc] init];
    _allFileID  = [[NSMutableArray alloc] init];
    _sections = [[NSMutableArray alloc] init];
    _sectionArrayRow = [[NSMutableDictionary alloc] init];
    _fileIDIndexPath = [[NSMutableDictionary alloc] init];
    
    _image = 0;
    _video = 0;
    _directories = 0;
    _files = 0;
    _totalSize = 0;
    
    return self;
}

@end


@implementation CCSection

//
// orderByField : nil, date, typeFile
//
+ (CCSectionDataSource *)creataDataSourseSectionMetadata:(NSArray *)records listProgressMetadata:(NSMutableDictionary *)listProgressMetadata groupByField:(NSString *)groupByField replaceDateToExifDate:(BOOL)replaceDateToExifDate activeAccount:(NSString *)activeAccount
{
    id dataSection;
    long counterSessionDownload = 0;
    long counterSessionUpload = 0;
    NSMutableArray *copyRecords = [[NSMutableArray alloc] init];
    NSMutableDictionary *dictionaryFileIDMetadataForIndexPath = [[NSMutableDictionary alloc] init];
    
    CCSectionDataSource *sectionDataSource = [[CCSectionDataSource alloc] init];
    
    /*
     Initialize datasource
    */
    
    NSInteger numDirectory = 0;
    BOOL directoryOnTop = [CCUtility getDirectoryOnTop];
    
    for (id record in records) {
        
        CCMetadata *metadata;
        
        // verify type of class
        if ([record isKindOfClass:[TableMetadata class]])
            metadata = [CCCoreData insertEntityInMetadata:record];
        else
            metadata = (CCMetadata *)record;
        
        // if exists replace date with exif date
        if (replaceDateToExifDate) {
            TableLocalFile *localFile = [CCCoreData getLocalFileWithFileID:metadata.fileID activeAccount:activeAccount];
            if (localFile.exifDate)
                metadata.date = localFile.exifDate;
        }

        if ([listProgressMetadata objectForKey:metadata.fileID] && [groupByField isEqualToString:@"session"]) {
            [copyRecords insertObject:metadata atIndex:0];
        } else {
            
            if ([metadata.typeFile isEqualToString: k_metadataTypeFile_directory] && directoryOnTop) {
                [copyRecords insertObject:metadata atIndex:numDirectory++];
            } else {
                [copyRecords addObject:metadata];
            }
        }
    }
    
    /*
     sectionArrayRow
    */
    
    for (CCMetadata *metadata in copyRecords) {
        
        // how many download underway (only for groupSession)
        if ([metadata.session containsString:@"download"] && [groupByField isEqualToString:@"session"]) {
            counterSessionDownload++;
            if (counterSessionDownload > MaxGroupBySessionDownloadDatasource)
                continue;
        }

        // how many upload underway (only for groupSession)
        if ([metadata.session containsString:@"upload"] && [groupByField isEqualToString:@"session"]) {
            counterSessionUpload++;
            if (counterSessionUpload > MaxGroupBySessionUploadDatasource)
                continue;
        }
        
        if ([metadata.session length] > 0 && [groupByField isEqualToString:@"session"]) {
            
            if ([metadata.session containsString:@"wwan"]) dataSection = [@"." stringByAppendingString:metadata.session];
            else dataSection = metadata.session;
            
        }
        else if ([groupByField isEqualToString:@"none"]) dataSection = @"_none_";
        else if ([groupByField isEqualToString:@"date"]) dataSection = [CCUtility datetimeWithOutTime:metadata.date];
        else if ([groupByField isEqualToString:@"alphabetic"]) dataSection = [[metadata.fileNamePrint substringToIndex:1] uppercaseString];
        else if ([groupByField isEqualToString:@"typefile"]) dataSection = metadata.typeFile;
        if (!dataSection) dataSection = @"_none_";
        
        NSMutableArray *metadatas = [sectionDataSource.sectionArrayRow objectForKey:dataSection];
        
        if (metadatas) {
            
            // ROW ++
            [metadatas addObject:metadata.fileID];
            [sectionDataSource.sectionArrayRow setObject:metadatas forKey:dataSection];
            
        } else {
            
            // SECTION ++
            metadatas = [[NSMutableArray alloc] initWithObjects:metadata.fileID, nil];
            [sectionDataSource.sectionArrayRow setObject:metadatas forKey:dataSection];
        }

        if (metadata && [metadata.fileID length] > 0)
            [dictionaryFileIDMetadataForIndexPath setObject:metadata forKey:metadata.fileID];
    }
    
    /*
    Sections order
    */
    
    BOOL ascending;
    
    if (replaceDateToExifDate || [groupByField isEqualToString:@"date"]) ascending = NO;
    else ascending = YES;
    
    NSArray *sortSections = [[sectionDataSource.sectionArrayRow allKeys] sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        
        if ([groupByField isEqualToString:@"session"]) {
        
            if ([obj1 isKindOfClass:[NSString class]] && [obj1 containsString:@"download"]) return NSOrderedAscending;
            if ([obj2 isKindOfClass:[NSString class]] && [obj2 containsString:@"download"]) return NSOrderedDescending;
        
            if ([obj1 isKindOfClass:[NSString class]] && [obj1 containsString:@"upload"]) return NSOrderedAscending;
            if ([obj2 isKindOfClass:[NSString class]] && [obj2 containsString:@"upload"]) return NSOrderedDescending;
        }
        
        // Directory at Top
        if ([obj1 isKindOfClass:[NSString class]] && [obj1 containsString: k_metadataTypeFile_directory]) return NSOrderedAscending;
        if ([obj2 isKindOfClass:[NSString class]] && [obj2 containsString: k_metadataTypeFile_directory]) return NSOrderedDescending;
        
        if (ascending) return [obj1 compare:obj2];
        else return [obj2 compare:obj1];
    }];
    
    /*
    create allFileID, allRecordsDataSource, fileIDIndexPath, section
    */
    
    NSInteger indexSection = 0;
    NSInteger indexRow = 0;
    
    for (id section in sortSections) {
        
        [sectionDataSource.sections addObject:section];
        
        NSArray *rows = [sectionDataSource.sectionArrayRow objectForKey:section];
        
        for (NSString *fileID in rows) {
            
            CCMetadata *metadata = [dictionaryFileIDMetadataForIndexPath objectForKey:fileID];
            
            if (metadata.fileID) {
                
                [sectionDataSource.allFileID addObject:metadata.fileID];
                [sectionDataSource.allRecordsDataSource setObject:metadata forKey:metadata.fileID];
                [sectionDataSource.fileIDIndexPath setObject:[NSIndexPath indexPathForRow:indexRow inSection:indexSection] forKey:metadata.fileID];
                
                if ([metadata.typeFile isEqualToString: k_metadataTypeFile_image])
                    sectionDataSource.image++;
                if ([metadata.typeFile isEqualToString: k_metadataTypeFile_video])
                    sectionDataSource.video++;
                if (metadata.directory)
                    sectionDataSource.directories++;
                else {
                    sectionDataSource.files++;
                    sectionDataSource.totalSize = sectionDataSource.totalSize + metadata.size;
                }
                
                indexRow++;
            }
        }
        indexSection++;
        indexRow = 0;
    }
    
    /*
    end
    */
    
    return sectionDataSource;
}

+ (void)removeAllObjectsSectionDataSource:(CCSectionDataSource *)sectionDataSource
{
    [sectionDataSource.allRecordsDataSource removeAllObjects];
    [sectionDataSource.allFileID removeAllObjects];
    [sectionDataSource.sections removeAllObjects];
    [sectionDataSource.sectionArrayRow removeAllObjects];
    [sectionDataSource.fileIDIndexPath removeAllObjects];
    
    sectionDataSource.image = 0;
    sectionDataSource.video = 0;
    sectionDataSource.directories = 0;
    sectionDataSource.files = 0;
    sectionDataSource.totalSize = 0;
}

@end


