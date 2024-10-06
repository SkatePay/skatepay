//
//  AWS.swift
//  SkateConnect
//
//  Created by Konstantin Yurchenko, Jr on 9/26/24.
//

import AWSS3
import AWSSDKIdentity
import ClientRuntime
import Foundation
import Smithy

enum ServiceHandlerError: Error {
    case authError
}

enum HandlerError: Error {
    case getObjectBody(String)
    case readGetObjectBody(String)
    case missingContents(String)
}

public class S3ServiceHandler {
    var s3Client: S3Client
    
    let region: String?

    public init(region: String? = nil,
                accessKeyId: String? = nil,
                secretAccessKey: String? = nil,
                sessionToken: String? = nil) async throws
    {
        do {
            self.region = region
            let s3Config = try await S3Client.S3ClientConfiguration()

            if let region = self.region {
                s3Config.region = region
            }

            if accessKeyId == nil {
                s3Client = S3Client(config: s3Config)
            } else {
                guard let keyId = accessKeyId,
                      let secretKey = secretAccessKey
                else {
                    throw ServiceHandlerError.authError
                }

                let credentials = AWSCredentialIdentity(
                    accessKey: keyId,
                    secret: secretKey,
                    sessionToken: sessionToken
                )
                let identityResolver = try StaticAWSCredentialIdentityResolver(credentials)

                let s3Config = try await S3Client.S3ClientConfiguration(
                    awsCredentialIdentityResolver: identityResolver,
                    region: self.region
                )
                s3Client = S3Client(config: s3Config)
            }
        } catch {
            print("Error initializing the AWS S3 client: ", dump(error))
            throw error
        }
    }

    public func setCredentials(accessKeyId: String, secretAccessKey: String,
                               sessionToken: String? = nil) async throws
    {
        do {
            let credentials: AWSCredentialIdentity = AWSCredentialIdentity(
                accessKey: accessKeyId,
                secret: secretAccessKey,
                sessionToken: sessionToken
            )
            let identityResolver = try StaticAWSCredentialIdentityResolver(credentials)

            let s3Config = try await S3Client.S3ClientConfiguration(
                awsCredentialIdentityResolver: identityResolver
            )

            if let region = region {
                s3Config.region = region
            }
            s3Client = S3Client(config: s3Config)
        } catch {
            print("ERROR: setCredentials:", dump(error))
            throw error
        }
    }

    public func resetCredentials() async throws {
        do {
            let s3Config = try await S3Client.S3ClientConfiguration()

            if let region = region {
                s3Config.region = region
            }

            s3Client = S3Client(config: s3Config)
        } catch {
            print("ERROR: resetCredentials:", dump(error))
            throw error
        }
    }
    
    public func createBucket(name: String) async throws {
        var input = CreateBucketInput(
            bucket: name
        )

        if let region = region {
            if region != "us-east-1" {
                input.createBucketConfiguration = S3ClientTypes.CreateBucketConfiguration(locationConstraint: S3ClientTypes.BucketLocationConstraint(rawValue: region))
            }
        }

        do {
            _ = try await s3Client.createBucket(input: input)
        }
        catch let error as BucketAlreadyOwnedByYou {
            print("The bucket '\(name)' already exists and is owned by you. You may wish to ignore this exception.")
            throw error
        }
        catch {
            print("ERROR: ", dump(error, name: "Creating a bucket"))
            throw error
        }
    }

    public func deleteBucket(name: String) async throws {
        let input = DeleteBucketInput(
            bucket: name
        )
        do {
            _ = try await s3Client.deleteBucket(input: input)
        }
        catch {
            print("ERROR: ", dump(error, name: "Deleting a bucket"))
            throw error
        }
    }

    public func uploadFile(bucket: String, key: String, fileUrl: URL, tagging: String = "") async throws {
        do {
            let fileData = try Data(contentsOf: fileUrl)
            let dataStream = ByteStream.data(fileData)

            let input = PutObjectInput(
                acl: S3ClientTypes.ObjectCannedACL.publicRead,
                body: dataStream,
                bucket: bucket,
                key: key,
                tagging: tagging
            )

            _ = try await s3Client.putObject(input: input)
        }
        catch {
            print("ERROR: ", dump(error, name: "Putting an object."))
            throw error
        }
    }

    public func createFile(bucket: String, key: String, withData data: Data) async throws {
        let dataStream = ByteStream.data(data)

        let input = PutObjectInput(
            body: dataStream,
            bucket: bucket,
            key: key
        )

        do {
            _ = try await s3Client.putObject(input: input)
        }
        catch {
            print("ERROR: ", dump(error, name: "Putting an object."))
            throw error
        }
    }

    public func downloadFile(bucket: String, key: String, to: String) async throws {
        let fileUrl = URL(fileURLWithPath: to).appendingPathComponent(key)

        let input = GetObjectInput(
            bucket: bucket,
            key: key
        )
        do {
            let output = try await s3Client.getObject(input: input)

            guard let body = output.body else {
                throw HandlerError.getObjectBody("GetObjectInput missing body.")
            }

            guard let data = try await body.readData() else {
                throw HandlerError.readGetObjectBody("GetObjectInput unable to read data.")
            }

            try data.write(to: fileUrl)
        }
        catch {
            print("ERROR: ", dump(error, name: "Downloading a file."))
            throw error
        }
    }

    public func readFile(bucket: String, key: String) async throws -> Data {
        let input = GetObjectInput(
            bucket: bucket,
            key: key
        )
        do {
            let output = try await s3Client.getObject(input: input)
            
            guard let body = output.body else {
                throw HandlerError.getObjectBody("GetObjectInput missing body.")
            }

            guard let data = try await body.readData() else {
                throw HandlerError.readGetObjectBody("GetObjectInput unable to read data.")
            }

            return data
        }
        catch {
            print("ERROR: ", dump(error, name: "Reading a file."))
            throw error
        }
   }

    public func copyFile(from sourceBucket: String, name: String, to destBucket: String) async throws {
        let srcUrl = ("\(sourceBucket)/\(name)").addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)

        let input = CopyObjectInput(
            bucket: destBucket,
            copySource: srcUrl,
            key: name
        )
        do {
            _ = try await s3Client.copyObject(input: input)
        }
        catch {
            print("ERROR: ", dump(error, name: "Copying an object."))
            throw error
        }
    }

    public func deleteFile(bucket: String, key: String) async throws {
        let input = DeleteObjectInput(
            bucket: bucket,
            key: key
        )

        do {
            _ = try await s3Client.deleteObject(input: input)
        }
        catch {
            print("ERROR: ", dump(error, name: "Deleting a file."))
            throw error
        }
    }

    public func listBucketFiles(bucket: String) async throws -> [String] {
        do {
            let input = ListObjectsV2Input(
                bucket: bucket
            )
            
            let output = s3Client.listObjectsV2Paginated(input: input)
            var names: [String] = []
            
            for try await page in output {
                guard let objList = page.contents else {
                    print("ERROR: listObjectsV2Paginated returned nil contents.")
                    continue
                }
                
                for obj in objList {
                    if let objName = obj.key {
                        names.append(objName)
                    }
                }
            }
            
            
            return names
        }
        catch {
            print("ERROR: ", dump(error, name: "Listing objects."))
            throw error
        }
    }
}

